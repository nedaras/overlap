const std = @import("std");
const hook = @import("hook.zig");

var n: u32 = 0;
fn frame(gui: hook.Gui) void {
    _ = gui;
    n += 1;
    if (n == 1000) {
        hook.unhook();
    }

    std.debug.print("frame\n", .{});
}

pub fn main() !void {
    try hook.run(.{
        .frame_cb = &frame,
    });
}
