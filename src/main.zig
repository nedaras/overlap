const std = @import("std");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client = try Client.init(allocator);
    defer client.deinit();

    var spotify = Spotify{
        .http_client = &client,
        .authorization = "Bearer ...",
    };

    try spotify.skipToNext();

    const track = try spotify.getCurrentlyPlayingTrack();
    defer track.deinit();

    for (track.value.item.album.images) |image| {
        std.debug.print("{d}x{d}: '{s}'\n", .{ image.width, image.height, image.url });
    }

    //var hook: Hook = .init;

    //try hook.attach();
    //defer hook.detach();

    //const gui = hook.gui();

    //const font = try hook.loadFont(allocator, "font.fat");
    //defer font.deinit(allocator);

    //while (true) {
    //try hook.newFrame();
    //defer hook.endFrame();

    //gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    //gui.text(.{ 200.0, 200.0 }, "Helo", 0xFFFFFFFF, font);
    //}
}
