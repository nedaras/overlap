const std = @import("std");
const hook = @import("hook.zig");
const gui = hook.gui;

// My solution of rendering fonts.
// We will have custom font format that will have bitmap fonts
// and just load it at runtime simple as that

var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
const allocator = da.allocator();

var img: hook.Image = undefined;

const fw = 10483;
const fh = 27;

// todo: add err handling for init
fn init() void {
    img = hook.loadImage(allocator, .{
        .width = fw,
        .height = fh,
        .format = .R,
        .data = @embedFile("gui/font.bmp"),
    }) catch unreachable;
}

fn cleanup() void {
    img.deinit();
}

var x: f32 = 0.0;

fn frame() !void {
    const slide = @mod(x, fw);
    defer x += 0.5;

    gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    gui.image(.{ slide, 300.0 }, .{ slide + fw, 300.0 + fh }, img);

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
