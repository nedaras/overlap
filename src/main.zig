const std = @import("std");
const hook = @import("hook.zig");
const gui = hook.gui;

fn frame() !void {
    gui.addRectFilled(.{ -0.5, -0.5 }, .{ 0.5, 0.5 }, 0xFFFFFFFF);
}

pub fn main() !void {
    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
    });
}
