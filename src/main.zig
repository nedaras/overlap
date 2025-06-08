const std = @import("std");
const hook = @import("hook.zig");

fn frame(gui: hook.Gui) !void {
    gui.addRectFilled(.{ 0.0, 0.0 }, .{ 100.0, 100.0 }, 0xFFFFFFFF);
    gui.addRectFilled(.{ 200.0, 200.0 }, .{ 400.0, 400.0 }, 0xFFFFFFFF);
}

pub fn main() !void {
    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
    });
}
