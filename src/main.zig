const std = @import("std");
const hook = @import("hook.zig");

var trc: std.builtin.StackTrace = .{
    .instruction_addresses = undefined,
    .index = undefined,
};

fn frame(gui: hook.Gui) !void {
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
    std.debug.print("dumping\n", .{});
    std.debug.dumpStackTrace(trc);

    std.heap.page_allocator.free(trc.instruction_addresses);
}
