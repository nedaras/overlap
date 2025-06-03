const std = @import("std");
const builtin = @import("builtin");
const process = std.process;
const http = std.http;
const base64 = std.base64;
const fmt = std.fmt;
const net = std.net;
const json = std.json;
const native_os = builtin.os.tag;
const Uri = std.Uri;
const Address = net.Address;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Spotify = struct {
    allocator: Allocator,
    http_client: *http.Client,

    client_id: *const [32]u8,
    code_verifier: *const [64]u8,

    redirect_uri: []const u8,

    pub fn generateOAuthUrl(self: Spotify) Allocator.Error![]u8 {
        var hash: [32]u8 = undefined;
        var challange: [43]u8 = undefined;

        Sha256.hash(self.code_verifier, &hash, .{});
        assert(base64.url_safe_no_pad.Encoder.encode(&challange, &hash).len == 43);

        return try fmt.allocPrint(self.allocator, "https://accounts.spotify.com/authorize?response_type=code&client_id={s}&scope=user-read-private+user-read-email&code_challenge_method=S256&code_challenge={s}&redirect_uri={s}", .{ 
            self.client_id,
            challange,
            self.redirect_uri
        });
    }

    pub fn retreiveAccessToken(self: Spotify, code: []const u8) !void {
        assert(code.len == 298);

        const payload = try fmt.allocPrint(self.allocator, "client_id={s}&grant_type=authorization_code&code={s}&redirect_uri={s}&code_verifier={s}", .{
            self.client_id,
            code,
            self.redirect_uri,
            self.code_verifier,
        });
        defer self.allocator.free(payload);

        var response = std.ArrayList(u8).init(self.allocator);
        errdefer response.deinit();

        const uri = Uri{
            .scheme = "https",
            .host = .{
                .raw = "accounts.spotify.com",
            },
            .path = .{
                .raw = "/api/token",
            },
        };

        var header_buf: [4096]u8 = undefined;
        var req = try self.http_client.open(.POST, uri, .{
            .server_header_buffer = &header_buf,
            .redirect_behavior = .not_allowed,
            .headers = .{
                .content_type = .{ .override = "application/x-www-form-urlencoded" }
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = payload.len };

        try req.send();
        try req.writeAll(payload);

        try req.finish();
        try req.wait();

        var json_reader = json.reader(self.allocator, req.reader());
        defer json_reader.deinit();

        const parsed = try json.parseFromTokenSource(struct {
            access_token: []const u8,
            token_type: []const u8,
            expires_in: u32,
            refresh_token: []const u8,
            scope: []const u8,
        }, self.allocator, &json_reader, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        std.debug.print("{s}\n", .{parsed.value.access_token});
        std.debug.print("{s}\n", .{parsed.value.token_type});
        std.debug.print("{d}\n", .{parsed.value.expires_in});
        std.debug.print("{s}\n", .{parsed.value.refresh_token});
        std.debug.print("{s}\n", .{parsed.value.scope});
    }

};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var gpa2 = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    defer _ = gpa2.deinit();

    const allocator = gpa.allocator();
    const debug_allocator = gpa2.allocator();

    const client_id = "4323d146458c487a9e69c8a6741c5a2b";
    const redirect_uri = "http%3A%2F%2F127.0.0.1%3A26822%2Foauth%2Fspotify";

    var code_verifier: [64]u8 = undefined;
    randomString(&code_verifier);

    var client = http.Client{
        .allocator = allocator,
    };
    defer client.deinit();

    const spotify = Spotify{
        .allocator = debug_allocator,
        .http_client = &client,
        .client_id = client_id,
        .code_verifier = &code_verifier,
        .redirect_uri = redirect_uri,
    };

    {
        const url = try spotify.generateOAuthUrl();
        defer debug_allocator.free(url);

        try openUrl(allocator, url);
    }

    const host = Address.initIp4(.{ 127, 0, 0, 1}, 26822);

    var server = try host.listen(.{ .kernel_backlog = 1, .reuse_address = true });
    defer server.deinit();

    const connection = try server.accept();

    var head_buf: [1024]u8 = undefined;
    var http_server = http.Server.init(connection, &head_buf);

    var req = try http_server.receiveHead();

    const code = req.head.target[20..];
    assert(code.len == 298);

    try spotify.retreiveAccessToken(code);

    //std.debug.print("{d}\n", .{fba.end_index});
    //std.debug.print("{s}\n", .{buf});

    //const payload = try fmt.allocPrint(allocator, "client_id={s}&grant_type=authorization_code&code={s}&redirect_uri={s}&code_verifier={s}", .{
        //client_id,
        //code,
        //redirect_uri,
        //code_verifier,
    //});
    //defer allocator.free(payload);

    //try req.respond(payload, .{ .keep_alive = false });

    //var response = std.ArrayList(u8).init(allocator);
    //defer response.deinit();

    //_ = try client.fetch(.{
        //.method = .POST,
        //.location = .{ .url = "https://accounts.spotify.com/api/token" },
        //.headers = .{
            //.content_type = .{ .override = "application/x-www-form-urlencoded" }
        //},
        //.redirect_behavior = .not_allowed,
        //.payload = payload,
        //.response_storage = .{
            //.dynamic = &response,
        //},
    //});

    //std.debug.print("{s}\n", .{response.items});
}

fn randomString(buf: []u8) void {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    std.crypto.random.bytes(buf);
    for (0..buf.len) |i| {
        buf[i] = chars[buf[i] % chars.len];
    }
}

fn openUrl(allocator: Allocator, url: []const u8) (process.Child.SpawnError || process.Child.WaitError)!void {
    const argv = blk: switch (native_os) {
        .windows => break :blk [_][]const u8{
            "rundll32",
            "url.dll,FileProtocolHandler",
            url,
        },
        .linux => break :blk [_][]const u8{
            "xdg-open",
            url,
        },
        else => @compileError("Opening url links for " ++ @tagName(native_os) ++ " is not supported."),
    };

    var child = process.Child.init(&argv, allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    try child.spawn();
    errdefer _ = child.kill() catch {};

    _ = try child.wait();
}
