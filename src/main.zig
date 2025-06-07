const std = @import("std");
const hook = @import("hook.zig");

fn frame(gui: hook.Gui) void {
    _ = gui;
}

pub fn main() !void {
    try hook.run(.{
        .frame_cb = &frame,
    });
}
