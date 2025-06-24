const std = @import("std");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const assert = std.debug.assert;

extern fn stbi_load_from_memory(
    buffer: [*]const u8,
    len: c_int,
    x: *c_int,
    y: *c_int,
    channels_in_file: *c_int,
    desired_channels: c_int,
) callconv(.C) ?[*]u8;

extern fn stbi_image_free(retval_from_stbi_load: [*]u8) callconv(.C) void;

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

    std.debug.print("{d}ms\n", .{track.value.progress_ms});

    const image = track.value.item.album.images[2];
    const uri = try std.Uri.parse(image.url);

    var buf: [512]u8 = undefined;
    var req = try client.open(.GET, uri, .{
        .server_header_buffer = &buf,
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    const image_buf = try allocator.alloc(u8, req.response.content_length.?);
    defer allocator.free(image_buf);

    assert(try req.readAll(image_buf) == image_buf.len);

    var w: c_int = 0;
    var h: c_int = 0;
    var c: c_int = 0;

    const img_ptr = stbi_load_from_memory(image_buf.ptr, @intCast(image_buf.len), &w, &h, &c, 4).?;
    defer stbi_image_free(img_ptr);

    std.debug.print("{d}x{d}: {d}\n", .{w, h, c});

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const img = try hook.loadImage(allocator, .{
        .format = .RGBA,
        .data = img_ptr[0..@intCast(w * h * c)],
        .width = @intCast(w),
        .height = @intCast(h),
    });
    defer img.deinit(allocator);

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(w), @floatFromInt(h) }, img);

        gui.text(.{ 200.0, 200.0 }, "Helogjk", 0xFFFFFFFF, font);
    }
}
