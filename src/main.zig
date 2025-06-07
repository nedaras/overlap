const std = @import("std");
const hook = @import("hook.zig");

fn frame(gui: hook.Gui) error{Testing}!void {
    _ = gui;
    try ohNoo();
}

fn ohNoo() !void {
    return error.Testing;
}

pub fn main() !void {
    try hook.run(.{
        .frame_cb = &frame,
    });
}
