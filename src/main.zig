const std = @import("std");
const Hook = @import("Hook.zig");
const windows = @import("windows.zig");
const unicode = std.unicode;
const Allocator = std.mem.Allocator;

const Context = struct {
    allocator: Allocator, // has to be threadsafe
};

pub fn propartiesChanged(context: *Context, session: windows.GlobalSystemMediaTransportControlsSession) !void {
    const properties = try (try session.TryGetMediaPropertiesAsync()).getAndForget(context.allocator);
    defer properties.Release();

    std.debug.print("title: {}\n", .{unicode.fmtUtf16Le(properties.Title())});
}

pub fn sessionChanged(context: *Context, manager: windows.GlobalSystemMediaTransportControlsSessionManager) !void {
    const session = (try manager.GetCurrentSession()) orelse return;
    defer session.Release();

    try propartiesChanged(context, session);

    _ = try session.MediaPropertiesChanged(context.allocator, context, propartiesChanged);
}

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{ .thread_safe = true }){};

    const allocator = debug_allocator.allocator();
    defer _ = debug_allocator.deinit(); // unsafe as those COM objects can have bigger lifespan than this stack function

    var context = Context{
        .allocator = allocator,
    };

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    const manager = try (try windows.GlobalSystemMediaTransportControlsSessionManager.RequestAsync()).getAndForget(allocator);
    defer manager.Release();

    try sessionChanged(&context, manager);

    // todo: remove this id
    _ = try manager.CurrentSessionChanged(allocator, &context, sessionChanged);

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();
    }
}
