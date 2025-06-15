const std = @import("std");
const hook = @import("hook.zig");
const gui = hook.gui;

// My solution of rendering fonts.
// As i will not allow customizing font family
// We will bake our fonts to msdf or jusr rasterize it we'll only use one font size 24pixels
// use smth like zstd to compress them
// And at runtime like decompress the a-zA-Z0-9 load to gpu
// And all other fonts like arabaic/emoji we will have LRU cache for them
// Only one problem kerning what todo with it i guess mono font but idk
// or we can store kern table

fn init() void {
    // it like means we have been hooked
    // create textures/fonts
}

fn cleanup() void {
    // called right before unhooking
    // after this call frame fn will not be called
}

fn frame() !void {
    gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    gui.rect(.{ 300.0, 300.0 }, .{ 600.0, 600.0 }, 0xFFFFFF7F);
    // such a simple function no?
    gui.text(.{ 200.0, 200.0 }, "Helo");
}

pub fn main() !void {
    const da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();
    _ = allocator;

    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
    });
}
