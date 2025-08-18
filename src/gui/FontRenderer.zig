const std = @import("std");
const fat = @import("fat");
const Atlas = @import("Atlas.zig");
const Allocator = std.mem.Allocator;

allocator: Allocator,

atlas: Atlas,

glyphs: std.AutoHashMapUnmanaged(Descriptor, Glyph),
fonts: std.ArrayListUnmanaged(fat.Face),

modified: u16 = 0,

pub const Glyph = struct {
    uv0: [2]f32,
    uv1: [2]f32,

    width: u32,
    height: u32,

    metrics: fat.Face.GlyphMetrics,
};

pub const Descriptor = struct {
    codepoint: u21,
    // size, weight, slant
};

const FontRenderer = @This();

pub fn init(allocator: Allocator) !FontRenderer {
    return .{
        .allocator = allocator,
        .atlas = try Atlas.init(allocator, 512),
        .glyphs = .empty,
        .fonts = .empty,
    };
}

pub fn deinit(self: *FontRenderer) void {
    for (self.fonts.items) |font| {
        font.close();
    }

    self.fonts.deinit(self.allocator);
    self.glyphs.deinit(self.allocator);
    self.atlas.deinit();
}

pub fn getGlyph(self: *FontRenderer, descriptor: Descriptor) !Glyph {
    if (self.glyphs.get(descriptor)) |glyph| {
        return glyph;
    }

    // idk render a square if null
    const font = (try getFont(self, descriptor)) orelse @panic("not implemented");
    const idx = font.glyphIndex(descriptor.codepoint).?;

    const render = try font.renderGlyph(self.allocator, idx);
    defer render.deinit(self.allocator);

    const rect = try self.atlas.reserve(render.width, render.height);

    for (0..rect.height) |y| {
        const src_i = render.width * y;
        const dst_i = self.atlas.size * (y + rect.y) + rect.x;

        @memcpy(self.atlas.data[dst_i..dst_i + render.width], render.bitmap[src_i..src_i + render.width]);
    }

    self.modified +%= 1;

    const altas_size: f32 = @floatFromInt(self.atlas.size);

    const glyph: Glyph = .{
        .uv0 = .{ @as(f32, @floatFromInt(rect.x)) / altas_size, @as(f32, @floatFromInt(rect.y)) / altas_size },
        .uv1 = .{ @as(f32, @floatFromInt(rect.x + render.width)) / altas_size, @as(f32, @floatFromInt(rect.y + render.height)) / altas_size },
        .width = render.width,
        .height = render.height,
        .metrics = try font.glyphMetrics(idx),
    };

    try self.glyphs.put(self.allocator, descriptor, glyph);

    return glyph;
}

fn getFont(self: *FontRenderer, descriptor: Descriptor) !?fat.Face {
    for (self.fonts.items) |font| {
        if (font.glyphIndex(descriptor.codepoint) != null) {
            return font;
        }
    }

    var it = try fat.iterateFonts(self.allocator, .{ .codepoint = descriptor.codepoint });
    defer it.deinit();

    while (try it.next()) |deffered_face| {
        defer deffered_face.deinit();

        if (!deffered_face.hasCodepoint(descriptor.codepoint)) {
            continue;
        }

        try self.fonts.append(self.allocator, try deffered_face.open(.{ .size = .{ .points = 16.0 }}));
        return self.fonts.getLast();
    }

    return null;
}
