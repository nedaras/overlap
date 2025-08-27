const std = @import("std");
const fat = @import("fat");
const Hook = @import("Hook.zig");
const windows = @import("windows.zig");
const unicode = std.unicode;
const Allocator = std.mem.Allocator;

const Context = struct {
    /// Must be threadsafe.
    allocator: Allocator,

    image_size: u32,

    mutex: std.Thread.Mutex = .{},
    modified: u16 = 0,

    image_pixels: ?*windows.IPixelDataProvider = null,

    title: []const u16 = &.{},
    artist: []const u16 = &.{},

    pub fn deinit(self: *Context) void {
        if (self.image_pixels) |image_pixels| {
            image_pixels.Release();
        }
        self.allocator.free(self.title);
        self.allocator.free(self.artist);
        self.* = undefined;
    }
};

pub fn propartiesChanged(context: *Context, session: windows.GlobalSystemMediaTransportControlsSession) !void {
    const properties = try (try session.TryGetMediaPropertiesAsync()).getAndForget(context.allocator);
    defer properties.Release();

    const thubnail = (try properties.Thumbnail()) orelse return;
    defer thubnail.Release();

    const stream = try (try thubnail.OpenReadAsync()).getAndForget(context.allocator);
    defer stream.Release();

    const decoder = try (try windows.BitmapDecoder.CreateAsync(@ptrCast(stream))).getAndForget(context.allocator);
    defer decoder.Release();

    const frame = try (try decoder.GetFrameAsync(0)).getAndForget(context.allocator);
    defer frame.Release();

    const transform = try windows.IBitmapTransform.new();
    defer transform.Release();

    transform.put_ScaledHeight(context.image_size);
    transform.put_ScaledWidth(context.image_size);

    transform.put_InterpolationMode(.Fant);

    const pixels = try (try frame.GetPixelDataTransformedAsync(
        windows.BitmapPixelFormat_Rgba8,
        windows.BitmapAlphaMode_Premultiplied,
        transform,
        windows.ExifOrientationMode_IgnoreExifOrientation,
        windows.ColorManagementMode_DoNotColorManage,
    )).getAndForget(context.allocator);
    errdefer pixels.Release();

    context.mutex.lock();
    defer context.mutex.unlock();

    if (context.image_pixels) |image_pixels| {
        image_pixels.Release();
    }

    context.allocator.free(context.title);
    context.allocator.free(context.artist);

    context.title = try context.allocator.dupe(u16, properties.Title());
    context.artist = try context.allocator.dupe(u16, properties.Artist());

    context.image_pixels = pixels;

    context.modified +%= 1;
}

pub fn sessionChanged(context: *Context, manager: windows.GlobalSystemMediaTransportControlsSessionManager) !void {
    const session = (try manager.GetCurrentSession()) orelse {
        context.mutex.lock();
        defer context.mutex.unlock();

        context.image_pixels = null;
        context.modified +%= 1;

        return;
    };
    defer session.Release();

    try propartiesChanged(context, session);

    _ = try session.MediaPropertiesChanged(context.allocator, context, propartiesChanged);
}

pub fn main() !void {
    var debug_allocator = std.heap.DebugAllocator(.{ .thread_safe = true }){};

    const allocator = debug_allocator.allocator();
    defer _ = debug_allocator.deinit(); // unsafe as those COM objects can have longer lifespan than this stack function

    var context = Context{
        .allocator = allocator,
        .image_size = 64,
    };
    defer context.deinit();

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    const manager = try (try windows.GlobalSystemMediaTransportControlsSessionManager.RequestAsync()).getAndForget(allocator);
    defer manager.Release();

    try sessionChanged(&context, manager);

    // todo: remove this id
    _ = try manager.CurrentSessionChanged(allocator, &context, sessionChanged);

    var hook: Hook = try .init();
    defer hook.deinit();

    try hook.attach(allocator);
    defer hook.detach();

    const gui = hook.gui();

    var image: ?Hook.Image = null;
    defer if (image) |img| {
        img.deinit(allocator);
    };

    var modified: u32 = 0;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        //try gui.text(.{ 0.0, 0.0 }, "HelloWorld!", .{});
        //try gui.text(.{ 0.0, 60.0 }, "MultipleFontSizes!", .{ .size = 64.0 });

        context.mutex.lock();
        defer context.mutex.unlock();

        blk: {
            defer modified = context.modified;
            if (modified == context.modified) break :blk;

            if (image) |img| {
                img.deinit(allocator);
                image = null;
            }

            const pixels = context.image_pixels orelse break :blk;

            var ptr: [*]const u8 = undefined;
            var len: u32 = undefined;
            pixels.DetachPixelData(&len, &ptr); // todo: add PixelDataProvider

            image = try hook.loadImage(allocator, .{
                .width = context.image_size,
                .height = context.image_size,
                .data = ptr[0..len],
                .format = .rgba,
            });
        }

        const cover = image orelse continue;

        const pos = &[2]f32{ 100.0, 100.0 };

        const image_size: f32 = @floatFromInt(context.image_size);
        const padding = 8.0;
        const width = 256.0;

        const x = 0;
        const y = 1;

        // background
        gui.rect(.{ -1.0 + pos[x], -1.0 + pos[y] }, .{ padding + pos[x] + width + padding + 1.0, padding + pos[y] + image_size + padding + 1.0 }, 0x202E36FF);
        gui.rect(.{ pos[x], pos[y] }, .{ padding + pos[x] + width + padding, padding + pos[y] + image_size + padding }, 0x10191EFF);

        // cover
        gui.image(.{ padding + pos[x], padding + pos[y] }, .{ padding + pos[x] + image_size, padding + pos[y] + image_size }, cover);

        // properties
        try gui.textW(.{ padding + pos[x] + image_size + padding, padding + pos[y] }, context.title, .{ .size = 12.0 });
        try gui.textW(.{ padding + pos[x] + image_size + padding, padding + 20.0 + pos[y] }, context.artist, .{ .size = 10.0, .color = 0x808080FF });
    }
}
