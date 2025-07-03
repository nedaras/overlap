const std = @import("std");
const windows = @import("../windows.zig");
const http = std.http;
const unicode = std.unicode;
const io = std.io;
const Allocator = std.mem.Allocator;
const Protocol = http.Client.Connection.Protocol;
const Uri = std.Uri;
const RequestTransfer = http.Client.RequestTransfer;
const assert = std.debug.assert;

// WinHttp handles pooling by it self.

allocator: Allocator,

handle: windows.HINTERNET,

const Client = @This();

pub const Response = struct {
    status: http.Status,

    /// If present, the number of bytes in the response body.
    content_length: ?u64 = null,

    /// `false`: headers. `true`: trailers.
    done: bool,

    /// Whether the response body should be skipped. Any data read from the
    /// response body will be discarded.
    skip: bool = false,
};

pub const Request = struct {
    handle: windows.HINTERNET,
    server_header_buffer: []u8,

    uri: Uri,
    client: *Client,
    connection: windows.HINTERNET,
    //keep_alive: bool,

    method: http.Method,
    transfer_encoding: RequestTransfer,

    /// The response associated with this request.
    ///
    /// This field is undefined until `wait` is called.
    response: Response,

    /// Standard headers that have default, but overridable, behavior.
    headers: Headers,

    pub const Headers = struct {
        authorization: Value = .default,

        pub const Value = union(enum) {
            default,
            omit,
            override: []const u8,
        };
    };

    pub fn deinit(req: *Request) void {
        windows.WinHttpCloseHandle(req.handle);
        windows.WinHttpCloseHandle(req.connection);

        req.* = undefined;
    }

    pub const SendError = error{
        NetworkUnreachable,
        InvalidWtf8,
        OutOfMemory,
        Unexpected,
    };

    pub fn send(req: Request) SendError!void {
        _ = try emitOverridableHeader(
            req,
            unicode.wtf8ToWtf16LeStringLiteral("Authorization: "),
            req.headers.authorization,
        );

        switch (req.transfer_encoding) {
            .content_length => |len| {
                var server_header: std.heap.FixedBufferAllocator = .init(req.server_header_buffer);

                const len_str = try std.fmt.allocPrint(server_header.allocator(), "{d}", .{len});

                const prefix = unicode.wtf8ToWtf16LeStringLiteral("Content-Length: ");
                const value = try unicode.wtf8ToWtf16LeAlloc(server_header.allocator(), len_str);

                const header = try server_header.allocator().alloc(u16, prefix.len + value.len);

                @memcpy(header[0..prefix.len], prefix);
                @memcpy(header[prefix.len .. prefix.len + value.len], value);

                try windows.WinHttpAddRequestHeaders(
                    req.handle,
                    header,
                    windows.WINHTTP_ADDREQ_FLAG_ADD | windows.WINHTTP_ADDREQ_FLAG_REPLACE,
                );
            },
            .chunked => {
                try windows.WinHttpAddRequestHeaders(
                    req.handle,
                    unicode.wtf8ToWtf16LeStringLiteral("Transfer-Encoding: chunked"),
                    windows.WINHTTP_ADDREQ_FLAG_ADD | windows.WINHTTP_ADDREQ_FLAG_REPLACE,
                );
            },
            .none => {},
        }

        // if we set it as GET and try to send some payload we get like err 87 invalid params or smth
        try windows.WinHttpSendRequest(
            req.handle,
            windows.WINHTTP_NO_ADDITIONAL_HEADERS,
            windows.WINHTTP_NO_REQUEST_DATA,
            windows.WINHTTP_IGNORE_REQUEST_TOTAL_LENGTH,
            null,
        );
    }

    pub fn write(req: *Request, bytes: []const u8) !usize {
        switch (req.transfer_encoding) {
            .chunked => {
                if (bytes.len > 0) {
                    var head_buf: [20]u8 = undefined;
                    const head = std.fmt.bufPrint(&head_buf, "{x}\r\n", .{bytes.len}) catch unreachable;

                    try req.innerWriteAll(head);
                    try req.innerWriteAll(bytes);
                    try req.innerWriteAll("\r\n");
                }

                return bytes.len;
            },
            .content_length => |*len| {
                if (len.* < bytes.len) return error.MessageTooLong;

                const amt = try windows.WinHttpWriteData(req.handle, bytes);
                len.* -= amt;
                return amt;
            },
            .none => return error.NotWriteable,
        }
    }

    pub fn writeAll(req: *Request, bytes: []const u8) !void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try write(req, bytes[index..]);
        }
    }

    pub fn finish(req: Request) !void {
        switch (req.transfer_encoding) {
            .chunked => try req.innerWriteAll("0\r\n\r\n"),
            .content_length => |len| if (len != 0) return error.MessageNotCompleted,
            .none => {},
        }
    }

    pub fn wait(req: *Request) !void {
        try windows.WinHttpReceiveResponse(req.handle);

        var status_code: windows.DWORD = 0;
        var status_code_size: windows.DWORD = @sizeOf(@TypeOf(status_code));

        windows.WinHttpQueryHeaders(
            req.handle,
            windows.WINHTTP_QUERY_STATUS_CODE | windows.WINHTTP_QUERY_FLAG_NUMBER,
            windows.WINHTTP_HEADER_NAME_BY_INDEX,
            &status_code,
            &status_code_size,
            windows.WINHTTP_NO_HEADER_INDEX,
        ) catch |err| return switch (err) {
            error.NoSpaceLeft => unreachable,
            error.HeaderNotFound => unreachable,
            else => |e| e,
        };

        req.response.status = @enumFromInt(status_code);

        var server_header: std.heap.FixedBufferAllocator = .init(req.server_header_buffer);

        if (try req.quearyHeader(server_header.allocator(), windows.WINHTTP_QUERY_CONTENT_LENGTH)) |content_lengt| {
            defer server_header.allocator().free(content_lengt);

            req.response.content_length = std.fmt.parseInt(u64, content_lengt, 10) catch return error.InvalidContentLength;
        }
    }

    fn quearyHeader(req: Request, allocator: Allocator, info: windows.DWORD) !?[]u8 {
        var header_len: windows.DWORD = 0;
        windows.WinHttpQueryHeaders(
            req.handle,
            info,
            null,
            null,
            &header_len,
            windows.WINHTTP_NO_HEADER_INDEX,
        ) catch |err| switch (err) {
            error.NoSpaceLeft => {},
            error.HeaderNotFound => return null,
            else => |e| return e,
        };

        const header = try allocator.alloc(u16, header_len >> 1);

        windows.WinHttpQueryHeaders(
            req.handle,
            windows.WINHTTP_QUERY_CONTENT_LENGTH,
            null,
            header.ptr,
            &header_len,
            windows.WINHTTP_NO_HEADER_INDEX,
        ) catch |err| return switch (err) {
            error.NoSpaceLeft => unreachable,
            error.HeaderNotFound => unreachable,
            else => |e| e,
        };

        const out = std.mem.sliceAsBytes(header);
        // this is just incorrect, but winhttp will soon be removed soo see no point to fixing this stuff
        const len = unicode.wtf16LeToWtf8(out, header);

        return allocator.remap(out, len - 1);
    }

    pub const ReadError = error{Unexpected};

    pub const Reader = io.Reader(*Request, ReadError, read);

    pub fn reader(req: *Request) Reader {
        return .{ .context = req };
    }

    pub fn read(req: *Request, buffer: []u8) ReadError!usize {
        if (req.response.skip) {
            while (try windows.WinHttpReadData(req.handle, buffer) != 0) {}

            req.response.done = true;
            return 0;
        }

        // need to handle compression maybe
        const amt = try windows.WinHttpReadData(req.handle, buffer);
        if (amt == 0) {
            req.response.done = true;
        }

        return amt;
        // need to handle trailing headers maybe
    }

    /// Reads data from the response body. Must be called after `wait`.
    pub fn readAll(req: *Request, buffer: []u8) !usize {
        var index: usize = 0;
        while (index < buffer.len) {
            const amt = try read(req, buffer[index..]);
            if (amt == 0) break;
            index += amt;
        }
        return index;
    }

    fn innerWriteAll(self: Request, bytes: []const u8) !void {
        var index: usize = 0;
        while (index < bytes.len) {
            index += try windows.WinHttpWriteData(self.handle, bytes);
        }
    }

    fn emitOverridableHeader(req: Request, prefix: []const u16, v: Headers.Value) !bool {
        switch (v) {
            .default => return true,
            .omit => return false,
            .override => |x| {
                var server_header: std.heap.FixedBufferAllocator = .init(req.server_header_buffer);

                const value = try unicode.wtf8ToWtf16LeAlloc(server_header.allocator(), x);
                const header = try server_header.allocator().alloc(u16, prefix.len + value.len);

                @memcpy(header[0..prefix.len], prefix);
                @memcpy(header[prefix.len .. prefix.len + value.len], value);

                try windows.WinHttpAddRequestHeaders(
                    req.handle,
                    header,
                    windows.WINHTTP_ADDREQ_FLAG_ADD | windows.WINHTTP_ADDREQ_FLAG_REPLACE,
                );

                return false;
            },
        }
    }
};

pub fn init(allocator: Allocator) !Client {
    return .{
        .allocator = allocator,
        .handle = try windows.WinHttpOpen(
            null,
            windows.WINHTTP_ACCESS_TYPE_NO_PROXY,
            windows.WINHTTP_NO_PROXY_NAME,
            windows.WINHTTP_NO_PROXY_BYPASS,
            0,
        ),
    };
}

pub fn deinit(client: Client) void {
    // For some reason it does not close pooled connections
    windows.WinHttpCloseHandle(client.handle);
}

pub const OpenError = error{
    UnsupportedUriScheme,
    UriMissingHost,
    OutOfMemory,
    InvalidWtf8,
    Unexpected,
};

pub fn open(
    client: *Client,
    method: http.Method,
    uri: Uri,
    options: RequestOptions,
) OpenError!Request {
    var server_header: std.heap.FixedBufferAllocator = .init(options.server_header_buffer);

    const protocol, const valid_uri = try validateUri(uri, server_header.allocator());
    const host = try unicode.wtf8ToWtf16LeAllocZ(server_header.allocator(), valid_uri.host.?.raw);
    const path = try unicode.wtf8ToWtf16LeAllocZ(server_header.allocator(), valid_uri.path.raw);

    const conn = try windows.WinHttpConnect(client.handle, host, uriPort(valid_uri, protocol));
    errdefer windows.WinHttpCloseHandle(conn);

    const flags: windows.DWORD = switch (protocol) {
        .plain => 0,
        .tls => windows.WINHTTP_FLAG_SECURE,
    };

    const req = try windows.WinHttpOpenRequest(
        conn,
        methodName(method),
        path,
        null,
        windows.WINHTTP_NO_REFERER,
        windows.WINHTTP_DEFAULT_ACCEPT_TYPES, // bad bad bad
        flags,
    );
    errdefer windows.WinHttpCloseHandle(req);

    return .{
        .handle = req,
        .server_header_buffer = options.server_header_buffer,
        .uri = valid_uri,
        .client = client,
        .connection = conn,
        .method = method,
        .transfer_encoding = .none,
        .response = .{
            .status = undefined,
            .done = false,
        },
        .headers = options.headers,
    };
}

pub const RequestOptions = struct {
    server_header_buffer: []u8,
    headers: Request.Headers = .{},
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

fn methodName(method: http.Method) [:0]const u16 {
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
