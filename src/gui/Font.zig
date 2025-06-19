const std = @import("std");
const fat = @import("../fat.zig");
const Image = @import("Image.zig");
const math = std.math;
const Allocator = std.mem.Allocator;

glyphs: []const fat.Glyph,
image: Image,

const Font = @This();

pub const Glyph = struct {
    size: [2]f32,
    bearing: [2]f32,
    uv_top: [2]f32,
    uv_bot: [2]f32,
    advance: f32,
};

pub fn deinit(self: Font, allocator: Allocator) void {
    allocator.free(self.glyphs);
    self.image.deinit(allocator);
}

pub fn loadGlyph(self: Font, unicode: u21) ?Glyph {
    const Context = struct {
        needle: u32,

        fn compare(ctx: @This(), g: fat.Glyph) math.Order {
            return math.order(ctx.needle, g.unicode);
        }
    };

    const idx = std.sort.binarySearch(fat.Glyph, self.glyphs, Context{ .needle = @intCast(unicode) }, Context.compare) orelse return null;
    const glyph = self.glyphs[idx];

    return .{
        .size = .{ @floatFromInt(glyph.width), @floatFromInt(glyph.height) },
        .bearing = .{ @floatFromInt(glyph.bearing_x), @floatFromInt(glyph.bearing_y) },
        .uv_top = .{
            @as(f32, @floatFromInt(glyph.off_x)) / @as(f32, @floatFromInt(self.image.width)),
            @as(f32, @floatFromInt(glyph.off_y)) / @as(f32, @floatFromInt(self.image.height)),
        },
        .uv_bot = .{
            @as(f32, @floatFromInt(glyph.off_x + glyph.width)) / @as(f32, @floatFromInt(self.image.width)),
            @as(f32, @floatFromInt(glyph.off_y + glyph.height)) / @as(f32, @floatFromInt(self.image.height)),
        },
        .advance = @floatFromInt(glyph.advance),
    };
}
