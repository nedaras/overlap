const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const unicode = std.unicode;
const http = std.http;
const Uri = std.Uri;
const Protocol = http.Client.Connection.Protocol;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

/// A set of linked lists of connections that can be reused.
pub const ConnectionPool = struct {
    mutex: std.Thread.Mutex = .{},
    /// Open connections that are currently in use.
    used: Queue = .{},
    /// Open connections that are not currently in use.
    free: Queue = .{},
    free_len: usize = 0,
    free_size: usize = 32,

    /// The criteria for a connection to be considered a match.
    pub const Criteria = struct {
        host: []const u8,
        port: u16,
        protocol: Protocol,
    };

    const Queue = std.DoublyLinkedList(windows.HINTERNET);
    pub const Node = Queue.Node;

    /// Finds and acquires a connection from the connection pool matching the criteria. This function is threadsafe.
    /// If no connection is found, null is returned.
    pub fn findConnection(pool: *ConnectionPool, criteria: Criteria) ?windows.HINTERNET {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        var next = pool.free.last;
        while (next) |node| : (next = node.prev) {
            if (node.data.protocol != criteria.protocol) continue;
            if (node.data.port != criteria.port) continue;

            // Domain names are case-insensitive (RFC 5890, Section 2.3.2.4)
            if (!std.ascii.eqlIgnoreCase(node.data.host, criteria.host)) continue;

            pool.acquireUnsafe(node);
            return &node.data;
        }

        return null;
    }

    /// Acquires an existing connection from the connection pool. This function is not threadsafe.
    pub fn acquireUnsafe(pool: *ConnectionPool, node: *Node) void {
        pool.free.remove(node);
        pool.free_len -= 1;

        pool.used.append(node);
    }

    /// Acquires an existing connection from the connection pool. This function is threadsafe.
    pub fn acquire(pool: *ConnectionPool, node: *Node) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        return pool.acquireUnsafe(node);
    }

    /// Tries to release a connection back to the connection pool. This function is threadsafe.
    /// If the connection is marked as closing, it will be closed instead.
    ///
    /// The allocator must be the owner of all nodes in this pool.
    /// The allocator must be the owner of all resources associated with the connection.
    pub fn release(pool: *ConnectionPool, allocator: Allocator, connection: *anyopaque) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        const node: *Node = @fieldParentPtr("data", connection);

        pool.used.remove(node);

        if (node.data.closing or pool.free_size == 0) {
            windows.WinHttpCloseHandle(node.data);
            return allocator.destroy(node);
        }

        if (pool.free_len >= pool.free_size) {
            const popped = pool.free.popFirst() orelse unreachable;
            pool.free_len -= 1;

            windows.WinHttpCloseHandle(popped.data);
            allocator.destroy(popped);
        }

        if (node.data.proxied) {
            pool.free.prepend(node); // proxied connections go to the end of the queue, always try direct connections first
        } else {
            pool.free.append(node);
        }

        pool.free_len += 1;
    }

    /// Adds a newly created node to the pool of used connections. This function is threadsafe.
    pub fn addUsed(pool: *ConnectionPool, node: *Node) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        pool.used.append(node);
    }

    /// Resizes the connection pool. This function is threadsafe.
    ///
    /// If the new size is smaller than the current size, then idle connections will be closed until the pool is the new size.
    pub fn resize(pool: *ConnectionPool, allocator: Allocator, new_size: usize) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        const next = pool.free.first;
        _ = next;
        while (pool.free_len > new_size) {
            const popped = pool.free.popFirst() orelse unreachable;
            pool.free_len -= 1;

            windows.WinHttpCloseHandle(popped.data);
            allocator.destroy(popped);
        }

        pool.free_size = new_size;
    }

    /// Frees the connection pool and closes all connections within. This function is threadsafe.
    ///
    /// All future operations on the connection pool will deadlock.
    pub fn deinit(pool: *ConnectionPool, allocator: Allocator) void {
        pool.mutex.lock();

        var next = pool.free.first;
        while (next) |node| {
            defer allocator.destroy(node);
            next = node.next;

            windows.WinHttpCloseHandle(node.data);
        }

        next = pool.used.first;
        while (next) |node| {
            defer allocator.destroy(node);
            next = node.next;

            windows.WinHttpCloseHandle(node.data);
        }

        pool.* = undefined;
    }
};

pub const Client = struct {
    handle: windows.HINTERNET,

    allocator: Allocator,
    connection_pool: ConnectionPool = .{},

    pub const RequestOptions = struct {
        server_header_buffer: []u8,
        headers: Headers = .{},
    };

    pub const RequestTransfer = union(enum) {
        content_length: u32,
        chunked: void,
        none: void,
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

    pub const Headers = struct {
        authorization: Value = .default,

        pub const Value = union(enum) {
            default,
            omit,
            override: []const u8,
        };
    };

    pub const Response = struct {
        status: http.Status,
    };

    pub const Request = struct {
        uri: Uri,

        connection: windows.HINTERNET,
        session: windows.HINTERNET,

        server_header_buffer: []u8,

        method: http.Method,
        transfer_encoding: RequestTransfer,
        headers: Headers,

        response: Response,

        pub fn deinit(self: Request) void {
            windows.WinHttpCloseHandle(self.session);
            windows.WinHttpCloseHandle(self.connection);
        }


        fn emitOverridableHeader(self: Request, prefix: []const u16, v: Headers.Value) !bool {
            switch (v) {
                .default => return true,
                .omit => return false,
                .override => |x| {
                    var server_header: std.heap.FixedBufferAllocator = .init(self.server_header_buffer);

                    const value = try unicode.wtf8ToWtf16LeAlloc(server_header.allocator(), x);
                    const header = try server_header.allocator().alloc(u16, prefix.len + value.len);

                    @memcpy(header[0..prefix.len], prefix);
                    @memcpy(header[prefix.len .. prefix.len + value.len], value);

                    try windows.WinHttpAddRequestHeaders(
                        self.session,
                        header,
                        windows.WINHTTP_ADDREQ_FLAG_ADD | windows.WINHTTP_ADDREQ_FLAG_REPLACE,
                    );

                    return false;
                },
            }
        }

        pub fn send(self: Request) !void {
            if (try emitOverridableHeader(self, unicode.wtf8ToWtf16LeStringLiteral("Authorization: "), self.headers.authorization)) {
                // ...
            }

            if (self.transfer_encoding == .chunked) {
                try windows.WinHttpAddRequestHeaders(
                    self.session,
                    unicode.wtf8ToWtf16LeStringLiteral("Transfer-Encoding: chunked"),
                    windows.WINHTTP_ADDREQ_FLAG_ADD | windows.WINHTTP_ADDREQ_FLAG_REPLACE,
                );
            }

            // we can set content_len greater then u32 up to u64, but i dont care
            const content_len = switch (self.transfer_encoding) {
                .chunked => windows.WINHTTP_IGNORE_REQUEST_TOTAL_LENGTH,
                .content_length => |len| len,
                .none => 0,
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
                index += try windows.WinHttpWriteData(self.session, bytes);
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

        const connection = try windows.WinHttpConnect(self.handle, host, uriPort(valid_uri, protocol));
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
            .server_header_buffer = options.server_header_buffer,
            .session = session,
            .method = method,
            .transfer_encoding = .none,
            .headers = options.headers,
            .response = .{
                .status = undefined,
            },
        };
    }

    pub fn deinit(self: *Client) void {
        assert(self.connection_pool.used.first == null); // There are still active requests.

        self.connection_pool.deinit(self.allocator);

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

fn connect(
    client: *Client,
    host: []const u16,
    port: u16,
    protocol: Protocol
) !windows.HINTERNET {
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
        .protocol = protocol, // useless
    })) |node| return node;

    const conn = try client.allocator.create(ConnectionPool.Node);
    errdefer client.allocator.destroy(conn);

    client.connection_pool.addUsed(conn);

    return conn.data;
}
