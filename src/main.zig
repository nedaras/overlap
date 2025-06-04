const std = @import("std");
const builtin = @import("builtin");
const Spotify = @import("Spotify.zig");
const hook = @import("hook.zig");
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

pub fn main() !void {
    if (native_os == .windows) {
        return hook.testing();
    }

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

    try spotify.retreiveAccessToken(code);

    try req.respond("You can close this window!", .{ .keep_alive = false });
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
}
