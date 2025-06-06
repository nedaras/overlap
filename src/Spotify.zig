const std = @import("std");
const http = std.http;
const fmt = std.fmt;
const json = std.json;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const Sha256 = crypto.hash.sha2.Sha256;
const Uri = std.Uri;
const base64 = std.base64;
const assert = std.debug.assert;

allocator: Allocator,
http_client: *http.Client,

client_id: *const [32]u8,
code_verifier: *const [64]u8,

redirect_uri: []const u8,

const Self = @This();

pub fn generateOAuthUrl(self: Self) Allocator.Error![]u8 {
    var hash: [32]u8 = undefined;
    var challange: [43]u8 = undefined;

    Sha256.hash(self.code_verifier, &hash, .{});
    assert(base64.url_safe_no_pad.Encoder.encode(&challange, &hash).len == 43);

    return try fmt.allocPrint(self.allocator, "https://accounts.spotify.com/authorize?response_type=code&client_id={s}&scope=user-read-playback-state+user-modify-playback-state&code_challenge_method=S256&code_challenge={s}&redirect_uri={s}", .{ self.client_id, challange, self.redirect_uri });
}

pub fn retreiveAccessToken(self: Self, code: []const u8) !void {
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
        .headers = .{ .content_type = .{ .override = "application/x-www-form-urlencoded" } },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = payload.len };

    try req.send();
    try req.writeAll(payload);

    try req.finish();
    try req.wait();

    // we need to walk jason without allocations would be rly rly rly nice

    var scanner = json.Scanner.initStreaming(self.allocator);
    defer scanner.deinit();

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
