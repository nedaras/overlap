const std = @import("std");
const http = std.http;
const fmt = std.fmt;
const json = std.json;
const Allocator = std.mem.Allocator;

client: http.Client,
client_id: []const u8,
verifier: []const u8,
redirect_uri: []const u8,

const Self = @This();

const Args = struct {
    client_id: []const u8,
    verifier: []const u8,
    redirect_uri: []const u8,
};

pub fn init(allocator: Allocator, args: Args) Self {
    return .{
        .client = http.Client{ 
            .allocator = allocator,
        },
        .client_id = args.client_id,
        .verifier = args.verifier,
        .redirect_uri = args.redirect_uri,
    };
}

pub fn deinit(spotify: *Self) void {
    spotify.client.deinit();
}

pub fn retreiveAccessToken(self: *Self, code: []const u8) !void {
    const payload = try fmt.allocPrint(self.client.allocator, "client_id={s}&grant_type=authorization_code&code={s}&redirect_uri={s}&code_verifier={s}", .{
        self.client_id,
        code,
        self.redirect_uri,
        self.verifier,
    });
    defer self.client.allocator.free(payload);

    var response = std.ArrayList(u8).init(self.client.allocator);
    defer response.deinit();

    const status = try self.client.fetch(.{
        .method = .POST,
        .location = .{ .url = "https://accounts.spotify.com/api/token" },
        .headers = .{ .content_type = .{ .override = "application/x-www-form-urlencoded" } },
        .redirect_behavior = .not_allowed,
        .payload = payload,
        .response_storage = .{ .dynamic = &response },
    });
    _  = status;

    std.debug.print("{s}\n", .{response.items});
}
