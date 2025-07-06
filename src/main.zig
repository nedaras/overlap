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

var debug_allocator = std.heap.DebugAllocator(.{ .thread_safe = true }){};
const allocator = debug_allocator.allocator();

const state = struct {
    var mutex: std.Thread.Mutex = .{};
    var title: ?[]const u8 = null;
};

fn proparitesChanged(session: windows.GlobalSystemMediaTransportControlsSession) !void {
    const props = try (try session.TryGetMediaPropertiesAsync()).getAndForget(allocator);
    defer props.Release();

    const thumbnail = (try props.Thumbnail()) orelse return;
    defer thumbnail.Release();

    const stream = try (try thumbnail.OpenReadAsync()).getAndForget(allocator);
    defer stream.Release();

    const decoder = try (try windows.BitmapDecoder.CreateAsync(@ptrCast(stream))).getAndForget(allocator);
    defer decoder.Release();

    const frame = try (try decoder.GetFrameAsync(0)).getAndForget(allocator);
    defer frame.Release();

    std.debug.print("{d}x{d}\n", .{frame.PixelWidth(), frame.PixelHeight()});

    const class = try windows.WindowsCreateString(
        unicode.wtf8ToWtf16LeStringLiteral(windows.IBitmapTransform.NAME),
    );
    defer windows.WindowsDeleteString(class);

    var transform: *windows.IBitmapTransform = undefined;

    try windows.RoGetActivationFactory(
        class,
        windows.IBitmapTransform.UUID,
        @ptrCast(&transform),
    );
    defer transform.Release();

    const pixels = try (try frame.GetPixelDataTransformedAsync(
        windows.BitmapPixelFormat_Rgba8,
        windows.BitmapAlphaMode_Premultiplied,
        &transform,
        windows.ExifOrientationMode_IgnoreExifOrientation,
        windows.ColorManagementMode_DoNotColorManage,
    )).getAndForget(allocator);
    defer pixels.Release();

    std.debug.print("got them pixels\n", .{});

    {
        state.mutex.lock();
        defer state.mutex.unlock();

        if (state.title) |title| {
            allocator.free(title);
        }

        // todo: calc size needed to alloc and reusize buf, idk why zig internaly uses std.Allocator fot this,
        //       mb we can fix this and post a pr
        state.title = try unicode.wtf16LeToWtf8Alloc(allocator, props.Title());
    }
}

fn sessionChanged(manager: windows.GlobalSystemMediaTransportControlsSessionManager) !void {
    std.debug.print("session changed\n", .{});

    const session = (try manager.GetCurrentSession()) orelse return;
    defer session.Release();

    _ = try session.MediaPropertiesChanged(allocator, {}, struct {
        fn invokeFn(_: void, sender: windows.GlobalSystemMediaTransportControlsSession) void {
            proparitesChanged(sender) catch unreachable;
        }
    }.invokeFn);
    // todo: remove prev sessions props changed event

    return proparitesChanged(session);
}

pub fn main() !void {
    // unsafe as those COM objects can have bigger lifespan than this stack function
    defer _ = debug_allocator.deinit();
    defer if (state.title) |title| {
        state.mutex.lock();
        defer state.mutex.unlock();

        allocator.free(title);
    };

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    const manager = try (try windows.GlobalSystemMediaTransportControlsSessionManager.RequestAsync()).getAndForget(allocator);
    defer manager.Release();

    _ = try manager.CurrentSessionChanged(allocator, {}, struct {
        fn invokeFn(_: void, sender: windows.GlobalSystemMediaTransportControlsSessionManager) void {
            sessionChanged(sender) catch unreachable;
        }
    }.invokeFn);
    // todo: defer remCSesChannged

    try sessionChanged(manager);

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();
    const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        state.mutex.lock();
        defer state.mutex.unlock();

        if (state.title) |title| {
            gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, title, 0xFFFFFFFF, font);
        }
    }
}
