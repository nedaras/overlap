const std = @import("std");
const hook = @import("hook.zig");
const gui = hook.gui;

fn frame() !void {
    gui.addRectFilled(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0xFFFFFFFF);
}

pub fn main() !void {
    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
    });
}
