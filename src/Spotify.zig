const std = @import("std");
const http = std.http;
const fmt = std.fmt;
const json = std.json;
const crypto = std.crypto;
const Allocator = std.mem.Allocator;
const Sha256 = crypto.hash.sha2.Sha256;
const base64 = std.base64.standard;

client: http.Client,
verifier: []const u8,

client_id: []const u8,
redirect_uri: []const u8,

const Self = @This();

const Args = struct {
    client_id: []const u8,
    redirect_uri: []const u8,
};

pub fn init(allocator: Allocator, args: Args) Allocator.Error!Self {
    const verifier = try allocator.alloc(u8, 64);
    randomString(verifier);

    return .{
        .client = http.Client{ 
            .allocator = allocator,
        },
        .verifier = verifier,
        .client_id = args.client_id,
        .redirect_uri = args.redirect_uri,
    };
}

pub fn deinit(self: *Self) void {
    self.client.allocator.free(self.verifier);
    self.client.deinit();
}

pub fn generateOAuthUrl(self: *Self) Allocator.Error![]u8 {
    var hash: [32]u8 = undefined;
    var challange: [44]u8 = undefined;

    Sha256.hash(self.verifier, &hash, .{});

    _ = std.base64.url_safe_no_pad.Encoder.encode(&challange, &hash);
    std.debug.print("{s}\n", .{self.verifier});
    std.debug.print("{s}\n", .{challange});

    return fmt.allocPrint(self.client.allocator, "https://accounts.spotify.com/authorize?response_type=code&client_id={s}&scope=user-read-private+user-read-email&code_challenge_method=S256&code_challenge={s}&redirect_uri={s}", .{self.client_id, challange, self.redirect_uri});
}

pub fn retreiveAccessToken(self: *Self, code: []const u8) !void {
    const payload = try fmt.allocPrint(self.client.allocator, "client_id={s}&grant_type=authorization_code&code={s}&redirect_uri={s}&code_verifier={s}", .{
        self.client_id,
        code,
        self.redirect_uri,
        self.verifier,
    });
    defer self.client.allocator.free(payload);

    std.debug.print("{s}\n", .{payload});

    var response = std.ArrayList(u8).init(self.client.allocator);
    defer response.deinit();

    const status = try self.client.fetch(.{
        .method = .POST,
        //.location = .{ .url = "https://accounts.spotify.com/api/token" },
        .location = .{ .url = "http://127.0.0.1:3000/api/token" },
        .headers = .{ 
            .content_type = .{ .override = "application/x-www-form-urlencoded" }
        },
        .redirect_behavior = .not_allowed,
        .payload = payload,
        .response_storage = .{ .dynamic = &response },
    });

    std.debug.print("{}\n{s}\n", .{status.status, response.items});
}

fn randomString(buf: []u8) void {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

    crypto.random.bytes(buf);
    for (0..buf.len) |i| {
        buf[i] = chars[buf[i] % chars.len];
    }
}
