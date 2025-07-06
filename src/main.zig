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

const global_allocator = std.heap.page_allocator;

fn proparitesChanged(session: windows.GlobalSystemMediaTransportControlsSession) !void {
    const props = try (try session.TryGetMediaPropertiesAsync()).getAndForget(global_allocator);
    defer props.Release();

    std.debug.print("{s}\n", .{std.mem.sliceAsBytes(props.Title())});
    std.debug.print("{s}\n", .{std.mem.sliceAsBytes(props.Artist())});
}

fn sessionChanged(manager: windows.GlobalSystemMediaTransportControlsSessionManager) !void {
    std.debug.print("session changed\n", .{});

    const session = (try manager.GetCurrentSession()) orelse return;
    defer session.Release();
     
    _ = try session.MediaPropertiesChanged(global_allocator, {}, struct {
        fn invokeFn(_: void, sender: windows.GlobalSystemMediaTransportControlsSession) void {
            proparitesChanged(sender) catch unreachable;
        }
    }.invokeFn);
    // todo: remove prev sessions props changed event

    return proparitesChanged(session);
}

pub fn main() !void {
    // we're doing smth bad with releases closes as we get crashes when cleaning up

    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    //const allocator = da.allocator();

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    const manager = try (try windows.GlobalSystemMediaTransportControlsSessionManager.RequestAsync()).getAndForget(global_allocator);
    defer manager.Release();

    _ = try manager.CurrentSessionChanged(global_allocator, {}, struct {
        fn invokeFn(_: void, sender: windows.GlobalSystemMediaTransportControlsSessionManager) void {
            sessionChanged(sender) catch unreachable;
        }
    }.invokeFn);
    // todo: defer remCSesChannged

    try sessionChanged(manager);

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
