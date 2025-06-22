const std = @import("std");
const http = @import("http.zig");
const Hook = @import("Hook.zig");

// For http i will not be using std.http cuz it is rly heavy
//   on windows we can use winhttp
//   on linux we can use libcurl

// Btw the access tokens and window we tryna hook should be passed by the injector/launcher

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    {
        const uri = std.Uri{
            .scheme = "https",
            .host = .{
                .raw = "httpbin.org",
            },
            .path = .{ .raw = "/anything" },
        };

        var server_header_buffer: [512]u8 = undefined;

        const client = try http.Client.init();
        defer client.deinit();

        var request = try client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer request.deinit();

        request.transfer_encoding = .chunked;

        try request.send();

        try request.writeAll("Hello\n");
        try request.writeAll("World!");

        try request.finish();

        try request.wait();

        std.debug.print("{}\n", .{request.response.status});

        var buf: [1024]u8 = undefined;
        while (true) {
            const amt = try request.read(&buf);
            if (amt == 0) break;

            std.debug.print("{s}", .{buf[0..amt]});
        }
        std.debug.print("\n", .{});
    }

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
