const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Hook = @import("Hook.zig");
const time = std.time;
const unicode = std.unicode;
const Uri = std.Uri;
const assert = std.debug.assert;

const windows = @import("windows.zig");

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    // todo: use WindowsCreateStringReference

    const class = try windows.WindowsCreateString(
        unicode.wtf8ToWtf16LeStringLiteral("Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager"),
    );
    defer windows.WindowsDeleteString(class);

    var manager: *windows.media.IGlobalSystemMediaTransportControlsSessionManagerStatics = undefined;

    try windows.RoGetActivationFactory(
        class,
        windows.media.IGlobalSystemMediaTransportControlsSessionManagerStatics.UUID,
        @ptrCast(&manager),
    );

    const future = try manager.RequestAsync();
    std.debug.print("{}\n", .{future.get_Status()});
    std.Thread.sleep(time.ns_per_s * 10);
    std.debug.print("{}\n", .{future.get_Status()});

    std.debug.print("{}\n", .{try future.GetResults()});

    var client = try Client.init(allocator);
    defer client.deinit();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    //const gui = hook.gui();
    //const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();
    }
}
