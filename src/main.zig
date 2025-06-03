const std = @import("std");
const builtin = @import("builtin");
const Spotify = @import("Spotify.zig");
const http = std.http;
const crypto = std.crypto;
const fmt = std.fmt;
const process = std.process;
const net = std.net;
const Sha256 = crypto.hash.sha2.Sha256;
const Uri = std.Uri;
const Allocator = std.mem.Allocator;
const base64 = std.base64.standard;
const native_os = builtin.os.tag;
const assert = std.debug.assert;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = false }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();


    var hash: [32]u8 = undefined;
    var verifier: [64]u8 = undefined;
    var challange: [44]u8 = undefined;

    randomString(crypto.random, &verifier);
    Sha256.hash(&verifier, &hash, .{});

    assert(base64.Encoder.encode(&challange, &hash).len == 44);

    var spotify = Spotify.init(allocator, .{
        .client_id = "4323d146458c487a9e69c8a6741c5a2b",
        .verifier = &verifier,
        .redirect_uri = "http://127.0.0.1:26822/oauth/spotify",
    });
    defer spotify.deinit();

    _ = try spotify.retreiveAccessToken("...");

    const url = try makeAuthUrl(allocator, .{
        .client_id = "4323d146458c487a9e69c8a6741c5a2b",
        .challange = &challange,
        .redirect_uri = "http://127.0.0.1:26822/oauth/spotify",
    });
    defer allocator.free(url);

    try openUrl(allocator, url);

    //const host = net.Address.initIp4(.{ 127, 0, 0, 1}, 26822);

    //var server = try host.listen(.{ .kernel_backlog = 1, .reuse_address = true });
    //defer server.deinit();

    //const connection = try server.accept();
    //const stream = connection.stream;

    //var buf: [4096]u8 = undefined;
    //const amt = try stream.read(&buf);

    //std.debug.print("{s}\n", .{buf[0..amt]});

    //try fmt.format(stream.writer(), "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{
        //verifier.len,
        //verifier,
    //});
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

const Args = struct {
    client_id: []const u8,
    challange: []const u8,
    redirect_uri: []const u8,
};

// there is no need to alloc this, but...
fn makeAuthUrl(allocator: Allocator, args: Args) error{OutOfMemory}![]u8 {
    return fmt.allocPrint(allocator, "https://accounts.spotify.com/authorize?response_type=code&client_id={s}&scope=user-read-private%20user-read-email&code_challenge_method=S256&code_challenge={s}&redirect_uri={s}", .{args.client_id, args.challange, args.redirect_uri});
}

fn randomString(random: std.Random, buf: []u8) void {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    random.bytes(buf);
    for (0..buf.len) |i| {
        buf[i] = chars[buf[i] % chars.len];
    }
}
