const std = @import("std");
const hook = @import("hook.zig");
const gui = hook.gui;

// My solution of rendering fonts.
// We will have custom font format that will have bitmap fonts
// and just load it at runtime simple as that

var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
const allocator = da.allocator();

var font: hook.Font = undefined;
var file: std.fs.File = undefined;

// todo: add err handling for init
fn init() void {
    font = hook.loadFont(allocator, file) catch unreachable;
}

fn cleanup() void {
    font.deinit();
}

var x: f32 = 0.0;

fn frame() !void {
    gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    //gui.text(.{ 200.0, 200.0 }, "Helo", font);
}

pub fn main() !void {
    defer _ = da.deinit();

    file = try std.fs.cwd().openFile("font.fat", .{});
    defer file.close();

    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
        .init_cb = &init,
    });
}
