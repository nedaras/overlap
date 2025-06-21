const std = @import("std");
const Hook = @import("hook2.zig");

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    var x: f32 = 0.0;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        x += 0.5;

        if (x > 420.0) {
            return error.Quit;
        }

        gui.rect(.{ 100.0 + x, 100.0 }, .{ 500.0 + x, 500.0 }, 0x0F191EFF);
        gui.text(.{ 200.0, 200.0 }, "Helo", font);
    }
}
