const std = @import("std");
const fat = @import("fat.zig");
const hook = @import("hook.zig");
const gui = hook.gui;

// My solution of rendering fonts.
// We will have custom font format that will have bitmap fonts
// and just load it at runtime simple as that

var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
const allocator = da.allocator();

var img: hook.Image = undefined;

var fw: u16 = undefined;
var fh: u16 = undefined;

// todo: add err handling for init
fn init() void {
    const font = @embedFile("gui/font.fat");
    var fbs = std.io.fixedBufferStream(font);

    const head = fbs.reader().readStruct(fat.Header) catch unreachable;
    for (0..head.glyphs_len) |_| {
        _ = fbs.reader().readStruct(fat.Glyph) catch unreachable;
    }

    fw = head.tex_width;
    fh = head.tex_height;

    img = hook.loadImage(allocator, .{
        .width = fw,
        .height = fh,
        .format = .R,
        .data = font[fbs.pos..],
    }) catch unreachable;
}

fn cleanup() void {
    img.deinit();
}

var x: f32 = 0.0;

fn frame() !void {
    const ffw: f32 = @floatFromInt(fw);
    const ffh: f32 = @floatFromInt(fh);

    const slide = @mod(x, ffw);
    defer x += 0.5;

    gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    gui.image(.{ slide, 300.0 }, .{ slide + ffw, 300.0 + ffh }, img);

    // such a simple function no?
    gui.text(.{ 200.0, 200.0 }, "Helo");
}

pub fn main() !void {
    defer _ = da.deinit();

    try hook.run(@TypeOf(frame), .{
        .frame_cb = &frame,
        .init_cb = &init,
    });
}
