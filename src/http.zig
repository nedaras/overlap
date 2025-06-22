const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const unicode = std.unicode;
const http = std.http;
const Uri = std.Uri;
const Protocol = http.Client.Connection.Protocol;
const Allocator = std.mem.Allocator;

pub const Client = struct {
    handle: windows.HINTERNET,

    pub const RequestOptions = struct {
        server_header_buffer: []u8,
    };

    pub const RequestTransfer = union(enum) {
        content_length: u32,
        chunked: void,
        none: void,
    };

    pub fn init() !Client {
        return .{
            .handle = try windows.WinHttpOpen(
                null,
                windows.WINHTTP_ACCESS_TYPE_NO_PROXY,
                windows.WINHTTP_NO_PROXY_NAME,
                windows.WINHTTP_NO_PROXY_BYPASS,
                0,
            ),
        };
    }

    pub const Response = struct {
        status: http.Status,
    };

    pub const Request = struct {
        uri: Uri,

        connection: windows.HINTERNET,
        session: windows.HINTERNET,

        method: http.Method,
        transfer_encoding: RequestTransfer,

        response: Response,

        pub fn deinit(self: Request) void {
            windows.WinHttpCloseHandle(self.session);
            windows.WinHttpCloseHandle(self.connection);
        }

        pub fn send(self: Request) !void {
            const content_len = switch (self.transfer_encoding) {
                .none => windows.WINHTTP_IGNORE_REQUEST_TOTAL_LENGTH,
                .content_length => |len| len,
                .chunked => 0,
            };

            try windows.WinHttpSendRequest(
                self.session,
                windows.WINHTTP_NO_ADDITIONAL_HEADERS,
                windows.WINHTTP_NO_REQUEST_DATA,
                content_len,
                null,
            );
        }

        fn writeAllInner(self: Request, bytes: []const u8) !void {
            var index: usize = 0;
            while (index < bytes.len) {
                index += try windows.WinHttpWriteData(self.connection, bytes);
            }
        }

        pub fn write(self: *Request, bytes: []const u8) !usize {
            switch (self.transfer_encoding) {
                .chunked => {
                    if (bytes.len > 0) {
                        var head_buf: [20]u8 = undefined;
                        const head = std.fmt.bufPrint(&head_buf, "{x}\r\n", .{bytes.len}) catch unreachable;

                        try self.writeAllInner(head);
                        try self.writeAllInner(bytes);
                        try self.writeAllInner("\r\n");
                    }

                    return bytes.len;
                },
                .content_length => |*len| {
                    if (len.* < bytes.len) return error.MessageTooLong;

                    const amt = try windows.WinHttpWriteData(self.session, bytes);
                    len.* -= amt;
                    return amt;
                },
                .none => return error.NotWriteable,
            }
        }

        pub fn writeAll(self: *Request, bytes: []const u8) !void {
            var index: usize = 0;
            while (index < bytes.len) {
                index += try write(self, bytes[index..]);
            }
        }

        pub fn finish(self: Request) !void {
            switch (self.transfer_encoding) {
                .chunked => try self.writeAllInner("0\r\n\r\n"),
                .content_length => |len| if (len != 0) return error.MessageNotCompleted,
                .none => {},
            }

            try windows.WinHttpReceiveResponse(self.session);
        }

        pub fn wait(self: *Request) !void {
            var status_code: windows.DWORD = 0;
            var status_code_size: windows.DWORD = @sizeOf(@TypeOf(status_code));

            try windows.WinHttpQueryHeaders(
                self.session,
                windows.WINHTTP_QUERY_STATUS_CODE | windows.WINHTTP_QUERY_FLAG_NUMBER,
                windows.WINHTTP_HEADER_NAME_BY_INDEX,
                &status_code,
                &status_code_size,
                windows.WINHTTP_NO_HEADER_INDEX,
            );

            self.response.status = @enumFromInt(status_code);
        }

        pub fn read(self: Request, buffer: []u8) !usize {
            return @intCast(try windows.WinHttpReadData(self.session, buffer));
        }
    };

    pub fn open(
        self: Client,
        method: http.Method,
        uri: Uri,
        options: RequestOptions,
    ) !Request {
        var server_header: std.heap.FixedBufferAllocator = .init(options.server_header_buffer);

        const protocol, const valid_uri = try validateUri(uri, server_header.allocator());

        const host = try unicode.wtf8ToWtf16LeAllocZ(server_header.allocator(), valid_uri.host.?.raw);
        const path = try unicode.wtf8ToWtf16LeAllocZ(server_header.allocator(), valid_uri.path.raw);

        const connection = try windows.WinHttpConnect(self.handle, host, uriPort(valid_uri, protocol), 0);
        errdefer windows.WinHttpCloseHandle(connection);

        const flags: windows.DWORD = switch (protocol) {
            .plain => 0,
            .tls => windows.WINHTTP_FLAG_SECURE,
        };

        const session = try windows.WinHttpOpenRequest(
            connection,
            methodNameW(method),
            path,
            null,
            windows.WINHTTP_NO_REFERER,
            windows.WINHTTP_DEFAULT_ACCEPT_TYPES,
            flags,
        );
        errdefer windows.WinHttpCloseHandle(session);

        // WinHttpAddRequestHeaders

        return .{
            .uri = valid_uri,
            .connection = connection,
            .session = session,
            .method = method,
            .transfer_encoding = .none,
            .response = .{
                .status = undefined,
            },
        };
    }

    pub fn deinit(self: Client) void {
        windows.WinHttpCloseHandle(self.handle);
    }
};

fn validateUri(uri: Uri, arena: Allocator) !struct { Protocol, Uri } {
    const protocol_map = std.StaticStringMap(Protocol).initComptime(.{
        .{ "http", .plain },
        .{ "ws", .plain },
        .{ "https", .tls },
        .{ "wss", .tls },
    });
    const protocol = protocol_map.get(uri.scheme) orelse return error.UnsupportedUriScheme;
    var valid_uri = uri;
    // The host is always going to be needed as a raw string for hostname resolution anyway.
    valid_uri.host = .{
        .raw = try (uri.host orelse return error.UriMissingHost).toRawMaybeAlloc(arena),
    };

    valid_uri.path = .{
        .raw = try uri.path.toRawMaybeAlloc(arena),
    };

    return .{ protocol, valid_uri };
}

fn uriPort(uri: Uri, protocol: Protocol) u16 {
    return uri.port orelse switch (protocol) {
        .plain => 80,
        .tls => 443,
    };
}

fn methodNameW(method: http.Method) [:0]const u16 {
    return switch (method) {
        .GET => unicode.wtf8ToWtf16LeStringLiteral("GET"),
        .HEAD => unicode.wtf8ToWtf16LeStringLiteral("HEAD"),
        .POST => unicode.wtf8ToWtf16LeStringLiteral("POST"),
        .PUT => unicode.wtf8ToWtf16LeStringLiteral("PUT"),
        .DELETE => unicode.wtf8ToWtf16LeStringLiteral("DELETE"),
        .CONNECT => unicode.wtf8ToWtf16LeStringLiteral("CONNECT"),
        .OPTIONS => unicode.wtf8ToWtf16LeStringLiteral("OPTIONS"),
        .TRACE => unicode.wtf8ToWtf16LeStringLiteral("TRACE"),
        .PATCH => unicode.wtf8ToWtf16LeStringLiteral("PATCH"),
        _ => unreachable,
    };
}
