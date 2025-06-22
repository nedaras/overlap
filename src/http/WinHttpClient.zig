const std = @import("std");
const windows = @import("../windows.zig");
const http = std.http;
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const Protocol = http.Client.Connection.Protocol;
const Uri = std.Uri;
const RequestTransfer = http.Client.RequestTransfer;
const assert = std.debug.assert;

allocator: Allocator,

handle: windows.HINTERNET,

connection_pool: ConnectionPool = .{},

const Client = @This();

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

    const Queue = std.DoublyLinkedList(Connection);
    pub const Node = Queue.Node;

    /// Finds and acquires a connection from the connection pool matching the criteria. This function is threadsafe.
    /// If no connection is found, null is returned.
    pub fn findConnection(pool: *ConnectionPool, criteria: Criteria) ?*Connection {
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
    pub fn release(pool: *ConnectionPool, allocator: Allocator, connection: *Connection) void {
        pool.mutex.lock();
        defer pool.mutex.unlock();

        const node: *Node = @fieldParentPtr("data", connection);

        pool.used.remove(node);

        if (node.data.closing or pool.free_size == 0) {
            node.data.close(allocator);
            return allocator.destroy(node);
        }

        if (pool.free_len >= pool.free_size) {
            const popped = pool.free.popFirst() orelse unreachable;
            pool.free_len -= 1;

            popped.data.close(allocator);
            allocator.destroy(popped);
        }

        if (false) { // node.data.proxied
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

            popped.data.close(allocator);
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

            node.data.close(allocator);
        }

        next = pool.used.first;
        while (next) |node| {
            defer allocator.destroy(node);
            next = node.next;

            node.data.close(allocator);
        }

        pool.* = undefined;
    }
};

pub const Connection = struct {
    handle: windows.HINTERNET,

    protocol: Protocol,
    host: []const u8,
    port: u16,

    closing: bool = false,

    pub fn close(conn: Connection, allocator: Allocator) void {
        windows.WinHttpCloseHandle(conn.handle);
        allocator.free(conn.host);
    }
};

pub const Response = struct {
    status: http.Status,

    /// `false`: headers. `true`: trailers.
    done: bool,
};

pub const Request = struct {
    handle: windows.HINTERNET,
    server_header_buffer: []u8,

    uri: Uri,
    client: *Client,
    // /// This is null when the connection is released.
    connection: *Connection,
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
        if (!req.response.done) {
            // If the response wasn't fully read, then we need to close the connection.
            req.connection.closing = true;
        }

        req.client.connection_pool.release(req.client.allocator, req.connection);

        windows.WinHttpCloseHandle(req.handle);

        req.* = undefined;
    }

    pub fn send(req: Request) !void {
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

        try windows.WinHttpReceiveResponse(req.handle);
    }

    pub fn wait(req: *Request) !void {
        var status_code: windows.DWORD = 0;
        var status_code_size: windows.DWORD = @sizeOf(@TypeOf(status_code));

        try windows.WinHttpQueryHeaders(
            req.handle,
            windows.WINHTTP_QUERY_STATUS_CODE | windows.WINHTTP_QUERY_FLAG_NUMBER,
            windows.WINHTTP_HEADER_NAME_BY_INDEX,
            &status_code,
            &status_code_size,
            windows.WINHTTP_NO_HEADER_INDEX,
        );

        req.response.status = @enumFromInt(status_code);
    }

    pub fn read(req: *Request, buffer: []u8) !usize {
        // need to handle compression maybe
        const amt = try windows.WinHttpReadData(req.handle, buffer);
        if (amt == 0) {
            req.response.done = true;
        }

        return amt;
        // need to handle trailing headers maybe
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

pub fn deinit(client: *Client) void {
    assert(client.connection_pool.used.first == null);

    client.connection_pool.deinit(client.allocator);

    windows.WinHttpCloseHandle(client.handle);
}

pub fn open(
    client: *Client,
    method: http.Method,
    uri: Uri,
    options: RequestOptions,
) !Request {
    var server_header: std.heap.FixedBufferAllocator = .init(options.server_header_buffer);

    const protocol, const valid_uri = try validateUri(uri, server_header.allocator());
    const path = try unicode.wtf8ToWtf16LeAllocZ(server_header.allocator(), valid_uri.path.raw);

    const conn = try connect(client, valid_uri.host.?.raw, uriPort(valid_uri, protocol), protocol);

    const flags: windows.DWORD = switch (protocol) {
        .plain => 0,
        .tls => windows.WINHTTP_FLAG_SECURE,
    };

    var req: Request = .{
        .handle = try windows.WinHttpOpenRequest(
            conn.handle,
            methodName(method),
            path,
            null,
            windows.WINHTTP_NO_REFERER,
            windows.WINHTTP_DEFAULT_ACCEPT_TYPES, // bad bad bad
            flags,
        ),
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
    errdefer req.deinit();

    return req;
}

pub fn connect(
    client: *Client,
    host: []const u8,
    port: u16,
    protocol: Protocol,
) !*Connection {
    if (client.connection_pool.findConnection(.{
        .host = host,
        .port = port,
        .protocol = protocol,
    })) |node| return node;

    const conn = try client.allocator.create(ConnectionPool.Node);
    errdefer client.allocator.destroy(conn);

    var wide_host: [256]u16 = undefined;
    const len = try unicode.wtf8ToWtf16Le(&wide_host, host);
    wide_host[len] = 0;

    const session = try windows.WinHttpConnect(client.handle, wide_host[0..len :0], port);
    errdefer windows.WinHttpCloseHandle(session);

    conn.data = .{
        .handle = session,
        .protocol = protocol,
        .host = try client.allocator.dupe(u8, host),
        .port = port,
    };

    client.connection_pool.addUsed(conn);

    return &conn.data;
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
