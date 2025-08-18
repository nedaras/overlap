const std = @import("std");
const fat = @import("fat");
const Hook = @import("Hook.zig");
const windows = @import("windows.zig");
const unicode = std.unicode;
const Allocator = std.mem.Allocator;

const Context = struct {
    /// Must be threadsafe.
    allocator: Allocator,

    mutex: std.Thread.Mutex = .{},
    modified: u16 = 0,

    image_width: u32 = 0,
    image_height: u32 = 0,
    image_pixels: ?*windows.IPixelDataProvider = null,

    pub fn deinit(self: *Context) void {
        if (self.image_pixels) |image_pixels| {
            image_pixels.Release();
        }
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

    context.image_width = frame.PixelWidth();
    context.image_height = frame.PixelHeight();
    context.image_pixels = pixels;

    context.modified +%= 1;
}

pub fn sessionChanged(context: *Context, manager: windows.GlobalSystemMediaTransportControlsSessionManager) !void {
    const session = (try manager.GetCurrentSession()) orelse {
        context.mutex.lock();
        defer context.mutex.unlock();

        context.image_width = 0;
        context.image_height = 0;
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

    const Atlas = @import("gui/Atlas.zig");

    var atlas = try Atlas.init(allocator, 512);
    defer atlas.deinit();

    var it = try fat.iterateFonts(allocator, .{ .family = "Arial" });
    defer it.deinit();

    const font = (try it.next()).?;
    defer font.deinit();

    const face = try font.open(.{ .size = .{ .points = 64.0 } });
    defer face.close();

    for ('A'..'z') |c| {
        const idx = face.glyphIndex(@intCast(c)) orelse continue;

        const bbox = try face.glyphBoundingBox(idx);
        const rect = try atlas.reserve(bbox.width, bbox.height);

        const render = try face.renderGlyph(allocator, idx);
        defer render.deinit(allocator);

        // todo: add like atlas.put or smth as this is mad
        for (0..render.height) |y| {
            const src_i = render.width * y;
            const dst_i = atlas.size * (y + rect.y) + rect.x;

            @memcpy(atlas.data[dst_i .. dst_i + render.width], render.bitmap[src_i .. src_i + render.width]);
        }
    }

    var context = Context{
        .allocator = allocator,
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

    const letter = try hook.loadImage(allocator, .{
        .data = atlas.data,
        .width = atlas.size,
        .height = atlas.size,
        .format = .r,
    });
    defer letter.deinit(allocator);

    var modified: u32 = 0;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        try gui.text(.{ 0.0, 0.0 }, "Hello World!");

        blk: {
            context.mutex.lock();
            defer context.mutex.unlock();
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
                .width = context.image_width,
                .height = context.image_height,
                .data = ptr[0..len],
                .format = .rgba,
            });
        }

        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(letter.width), @floatFromInt(letter.height) }, letter);

        if (image) |img| {
            gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(img.width), @floatFromInt(img.height) }, img);
        }
    }
}
