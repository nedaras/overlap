const std = @import("std");
const Client = @import("http.zig").Client;
const Uri = std.Uri;

http_client: *Client,

authorization : []const u8,

const Spotify = @This();

pub fn getAvailableDevices(self: *Spotify) !void {
    var buf: [1024]u8 = undefined;

    var req = try self.http_client.open(.GET, uri("/me/player/devices"), .{
        .server_header_buffer = &buf,
        .headers = .{
            .authorization = .{ .override = self.authorization },
        },
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    while (true) {
        const amt = try req.read(&buf);
        if (amt == 0) break;

        std.debug.print("{s}", .{buf[0..amt]});
    }
    std.debug.print("\n", .{});
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
