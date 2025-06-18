const std = @import("std");
const hook = @import("hook.zig");
const gui = hook.gui;

// My solution of rendering fonts.
// We will have custom font format that will have bitmap fonts
// and just load it at runtime simple as that

var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
const allocator = da.allocator();

var img: hook.Image = undefined;

// todo: add err handling for init
fn init() void {
    img = hook.loadImage(allocator, .{
        .width = 299,
        .height = 22,
        .format = .R,
        .data = @embedFile("gui/font.bmp"),
    }) catch unreachable;
}

fn cleanup() void {
    img.deinit();
}

fn frame() !void {
    gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    //gui.rect(.{ 300.0, 300.0 }, .{ 600.0, 600.0 }, 0xffffff7f);
    gui.image(.{ 300.0, 300.0 }, .{ 300.0 + 299.0, 300.0 + 22.0 }, img);

    // such a simple function no?
    gui.text(.{ 200.0, 200.0 }, "Helo");
}

pub fn main() !void {
    defer _ = da.deinit();

    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
        .init_cb = &init,
    });
}
