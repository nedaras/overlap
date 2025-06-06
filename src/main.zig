const std = @import("std");
const hook = @import("hook.zig");

fn frame(gui: hook.Gui) void {
    _ = gui;
    std.debug.print("frame\n", .{});
}

pub fn main() !void {
    try hook.run(.{
        .frame_cb = &frame,
    });
}
