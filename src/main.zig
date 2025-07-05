const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Hook = @import("Hook.zig");
const time = std.time;
const unicode = std.unicode;
const windows = @import("windows.zig");
const Uri = std.Uri;
const assert = std.debug.assert;

// todos: Make Player class so i would not need to look at windows
//        Read album image
//        hook to track change and session chnage events

pub fn main() !void {
    // we're doing smth bad with releases closes as we get crashes when cleaning up

    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    //const allocator = da.allocator();

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    // mybe move this media to just windows
    // ok bug is tha our callback made with allocator can be freed after some long time like out of this scope when da.deinit is called
    // so it can panick that mem leaked or it can double down and crash as when "leak" is detected our callback tries to free stuff
    // soo da_allocator is unsafe here
    const manager = try (try windows.GlobalSystemMediaTransportControlsSessionManager.RequestAsync()).getAndForget(std.heap.page_allocator);
    defer manager.Release();

    const session = (try manager.GetCurrentSession()) orelse return error.NoSession;
    defer session.Release();

    _ = try session.MediaPropertiesChanged(std.heap.page_allocator, {}, struct {
        fn invokeFn(_: void, sender: windows.GlobalSystemMediaTransportControlsSession) void {
            const props = (sender.TryGetMediaPropertiesAsync() catch unreachable).getAndForget(std.heap.page_allocator) catch unreachable;
            defer props.Release();

            std.debug.print("{s}\n", .{std.mem.sliceAsBytes(props.Title())});
            std.debug.print("{s}\n", .{std.mem.sliceAsBytes(props.Artist())});
        }
    }.invokeFn);

    const props = try (try session.TryGetMediaPropertiesAsync()).getAndForget(std.heap.page_allocator);
    defer props.Release();

    std.debug.print("{s}\n", .{std.mem.sliceAsBytes(props.Title())});
    std.debug.print("{s}\n", .{std.mem.sliceAsBytes(props.Artist())});

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    //const gui = hook.gui();
    //const input = hook.input();

    //const font = try hook.loadFont(allocator, "font.fat");
    //defer font.deinit(allocator);

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();
    }
}
