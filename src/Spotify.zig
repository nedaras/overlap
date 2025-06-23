const std = @import("std");
const json = std.json;
const Client = @import("http.zig").Client;
const Uri = std.Uri;

http_client: *Client,

authorization : []const u8,

const Spotify = @This();

pub const Track = struct {
    timestamp: u64,
    progress_ms: u32,
};

pub fn getCurrentlyPlayingTrack(self: *Spotify) !json.Parsed(Track) {
    const allocator = self.http_client.allocator;
    var buf: [1024]u8 = undefined;

    var req = try self.http_client.open(.GET, uri("/me/player/currently-playing"), .{
        .server_header_buffer = &buf,
        .headers = .{
            .authorization = .{ .override = self.authorization },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    if (req.response.status != .ok) {
        return error.BadResponse;
    }

    var json_reader = json.reader(allocator, req.reader());
    defer json_reader.deinit();

    const options: json.ParseOptions = .{
        .allocate = .alloc_if_needed,
        .ignore_unknown_fields = true,
        .duplicate_field_behavior = .use_first,
    };

    return json.parseFromTokenSource(
        Track,
        allocator,
        &json_reader,
        options,
    );
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
