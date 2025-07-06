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
    var width: u32 = 0;
    var height: u32 = 0;
    var pixel_data: ?*windows.IPixelDataProvider = null;
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

    var factory: *windows.IActivationFactory = undefined;
    var transform: *windows.IBitmapTransform = undefined;

    try windows.RoGetActivationFactory(
        class,
        windows.IActivationFactory.UUID,
        @ptrCast(&factory),
    );
    defer factory.Release();

    try factory.ActivateInstance(@ptrCast(&transform));
    defer transform.Release();

    // maybe we can activate our callbacks like this cuz then our out of stack allocator problems would disolve

    const pixels = try (try frame.GetPixelDataTransformedAsync(
        windows.BitmapPixelFormat_Rgba8,
        windows.BitmapAlphaMode_Premultiplied,
        transform,
        windows.ExifOrientationMode_IgnoreExifOrientation,
        windows.ColorManagementMode_DoNotColorManage,
    )).getAndForget(allocator);
    errdefer pixels.Release();

    {
        state.mutex.lock();
        defer state.mutex.unlock();

        if (state.title) |title| {
            allocator.free(title);
        }

        if (state.pixel_data) |pixel_data| {
            pixel_data.Release();
        }

        // todo: calc size needed to alloc and reusize buf, idk why zig internaly uses std.Allocator fot this,
        //       mb we can fix this and post a pr
        state.title = try unicode.wtf16LeToWtf8Alloc(allocator, props.Title());
        state.width = frame.PixelWidth();
        state.height = frame.PixelHeight();
        state.pixel_data = pixels;
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

    var image: ?Hook.Image = null;
    defer if (image) |img| {
        img.deinit(allocator);
    };

    const gui = hook.gui();
    //const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    var prev_first_char: u8 = '\x00';

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        state.mutex.lock();
        defer state.mutex.unlock();

        const pixel_data = state.pixel_data orelse continue;
        const title = state.title orelse continue;

        // this is just stoopid, but works for testing
        defer prev_first_char = title[0];
        if (prev_first_char != title[0]) {
            var len: u32 = undefined;
            var ptr: [*]const u8 = undefined;

            pixel_data.DetachPixelData(&len, &ptr);

            if (image == null or image.?.width != state.width or image.?.height != state.height) {
                if (image) |img| {
                    img.deinit(allocator);
                    image = null;
                }

                image = try hook.loadImage(allocator, .{
                    .width = state.width,
                    .height = state.height,
                    .data = ptr[0..len],
                    .format = .rgba,
                    .usage = .dynamic,
                });
            } else {
                try hook.updateImage(image.?, ptr[0..len]);
            }
        }

        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(state.width), @floatFromInt(state.height) }, image.?);

        //if (state.title) |title| {
            //gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, title, 0xFFFFFFFF, font);
        //}
    }
}
