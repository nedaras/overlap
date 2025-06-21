const std = @import("std");
const http = @import("http.zig");
const Hook = @import("Hook.zig");

// For http i will not be using std.http cuz it is rly heavy
//   on windows we can use winhttp
//   on linux we can use libcurl

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client: http.Client = .{};
    defer client.deinit();

    try client.open();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        gui.text(.{ 200.0, 200.0 }, "Helo", 0xFFFFFFFF, font);
    }
}
