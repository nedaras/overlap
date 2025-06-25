const std = @import("std");
const json = std.json;
const http = std.http;
const Client = @import("http.zig").Client;
const Uri = std.Uri;
const assert = std.debug.assert;

http_client: *Client,

authorization: []const u8,

const Spotify = @This();

pub const Track = struct {
    timestamp: u64,
    progress_ms: u32,
    item: struct { // can be null!!!
        album: struct {
            images: [3]struct {
                url: []const u8,
                height: u16,
                width: u16,
            },
        },
        name: []const u8,
    },
};

pub fn getCurrentlyPlayingTrack(self: *Spotify) !json.Parsed(Track) {
    const allocator = self.http_client.allocator;
    var header_buf: [4 * 1024]u8 = undefined;

    var req = try self.http_client.open(.GET, uri("/me/player/currently-playing"), .{
        .server_header_buffer = &header_buf,
        .headers = .{
            .authorization = .{ .override = self.authorization },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    if (req.response.status != .ok) {
        req.response.skip = true;
        assert(try req.read(&header_buf) == 0);

        return switch (req.response.status) {
            .ok => unreachable,
            .no_content => error.DeviceNotFound,
            .unauthorized => error.Unauthorized, // this should be handled
            .forbidden => error.Forbiden,
            .too_many_requests => error.RateLimited, // this should be handled
            else => |x| {
                std.debug.print("{}\n", .{x});
                return error.InvalidStatusCode;
            },
        };
    }

    var json_reader = json.reader(allocator, req.reader());
    defer json_reader.deinit();

    const options: json.ParseOptions = .{
        .ignore_unknown_fields = true,
    };

    return json.parseFromTokenSource(
        Track,
        allocator,
        &json_reader,
        options,
    );
}

pub fn skipToNext(self: *Spotify) !void {
    var header_buf: [4 * 1024]u8 = undefined;

    var req = try self.http_client.open(.POST, uri("/me/player/next"), .{
        .server_header_buffer = &header_buf,
        .headers = .{
            .authorization = .{ .override = self.authorization },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    req.response.skip = true;
    assert(try req.read(&header_buf) == 0);

    return switch (req.response.status) {
        .ok, .no_content => {},
        .unauthorized => error.Unauthorized, // this should be handled
        .forbidden => error.Forbiden,
        .too_many_requests => error.RateLimited, // this should be handled
        .not_found => error.DeviceNotFound,
        else => |x| {
            std.debug.print("{}\n", .{x});
            return error.InvalidStatusCode;
        },
    };
}

pub fn skipToPrevious(self: *Spotify) !void {
    var header_buf: [4 * 1024]u8 = undefined;

    var req = try self.http_client.open(.POST, uri("/me/player/previous"), .{
        .server_header_buffer = &header_buf,
        .headers = .{
            .authorization = .{ .override = self.authorization },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    req.response.skip = true;
    assert(try req.read(&header_buf) == 0);

    return switch (req.response.status) {
        .ok, .no_content => {},
        .unauthorized => error.Unauthorized, // this should be handled
        .forbidden => error.Forbiden,
        .too_many_requests => error.RateLimited, // this should be handled
        .not_found => error.DeviceNotFound,
        else => |x| {
            std.debug.print("{}\n", .{x});
            return error.InvalidStatusCode;
        },
    };
}

fn uri(comptime path: []const u8) Uri {
    return .{
        .scheme = "https",
        .host = .{
            .raw = "api.spotify.com",
        },
        .path = .{
            .raw = "v1" ++ path,
        },
    };
}
