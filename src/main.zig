const std = @import("std");
const hook = @import("hook.zig");

fn frame(gui: hook.Gui) !void {
    _ = gui;
    try ohNoo();
}

fn ohNoo() !void {
    return error.Testing;
}

pub fn main() !void {
    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
    });
}
