const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const assert = std.debug.assert;

const Command = enum {
    curr,
    next,
    previous,
};

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client = try Client.init(allocator);
    defer client.deinit();

    var spotify = Spotify{
        .http_client = &client,
        .authorization = "Bearer ...",
    };

    var action: actions.SingleAction(sendCommand) = undefined;

    try action.init(allocator);
    defer action.deinit();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();
    const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    // mb dont do it here
    const cover = blk: {
        const stb_image = try sendCommand(&spotify, .curr);
        defer stb_image.deinit();

        break :blk try hook.loadImage(allocator, .{
            .data = stb_image.data,
            .width = stb_image.width,
            .height = stb_image.height,
            .format = .rgba,
            .usage = .dynamic,
        });
    };
    defer cover.deinit(allocator);

    var prev_mouse_ldown = false;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        defer prev_mouse_ldown = input.mouse_ldown;

        if (action.dispatch()) |x| {
            const stb_image: stb.Image = try x;
            defer stb_image.deinit();

            try hook.updateImage(cover, stb_image.data);
        }

        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(cover.width), @floatFromInt(cover.height) }, cover);
        if (action.busy()) {
            //gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
            gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, "Sending...", 0xFFFFFFFF, font);
        } else {
            const click = !prev_mouse_ldown and input.mouse_ldown;
            const in_bounds = input.mouse_x <= cover.width and input.mouse_y <= cover.height;
            if (click and in_bounds) {
                try action.post(.{ &spotify, .next });
            }

            gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, "Helo", 0xFFFFFFFF, font);
        }
    }
}

// curr problems...
// spotify width height for image can lie
// and it seems getting curr track after skip sometimes just returnes same track
fn sendCommand(spotify: *Spotify, cmd: Command) !stb.Image {
    const allocator = spotify.http_client.allocator;

    switch (cmd) {
        .curr => {},
        .next => try spotify.skipToNext(),
        .previous => try spotify.skipToPrevious(),
    }

    const track = try spotify.getCurrentlyPlayingTrack();
    defer track.deinit();

    const uri = try std.Uri.parse(track.value.item.album.images[0].url);

    var server_header: [256]u8 = undefined;

    var req = try spotify.http_client.open(.GET, uri, .{
        .server_header_buffer = &server_header,
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    const image = try allocator.alloc(u8, req.response.content_length.?);
    defer allocator.free(image);

    try req.reader().readNoEof(image);

    return stb.loadImageFromMemory(image, .{
        .channels = .rgba,
    });
}
