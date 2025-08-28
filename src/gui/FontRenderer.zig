const std = @import("std");
const fat = @import("fat");
const Atlas = @import("Atlas.zig");
const Backend = @import("Backend.zig");
const Allocator = std.mem.Allocator;

allocator: Allocator,

atlas: Atlas,

glyphs: std.AutoHashMapUnmanaged(Descriptor, Glyph),
fonts: std.ArrayListUnmanaged(fat.Face),

pub const Glyph = struct {
    uv0: [2]f32,
    uv1: [2]f32,

    width: u32,
    height: u32,

    metrics: fat.Face.GlyphMetrics,
};

pub const Descriptor = struct {
    codepoint: u21,
    size: u32,
    // size, weight, slant
};

const FontRenderer = @This();

pub fn init(allocator: Allocator, backend: Backend) !FontRenderer {
    return .{
        .allocator = allocator,
        .atlas = try Atlas.init(allocator, backend, 512),
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
    // todo: fix space char as some weird shit happens when passing it
    const idx = font.glyphIndex(descriptor.codepoint).?;

    const render = try font.renderGlyph(self.allocator, idx);
    defer render.deinit(self.allocator);

    if (render.width == 0 or render.height == 0) {
        return .{
            .uv0 = .{ 0.0, 0.0 },
            .uv1 = .{ 0.0, 0.0 },
            .width = 0,
            .height = 0,
            .metrics = try font.glyphMetrics(idx),
        };
    }

    const rect = try self.atlas.reserve(render.width, render.height);
    try self.atlas.fill(rect, render.bitmap);

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
    for (self.fonts.items) |*font| {
        if (font.glyphIndex(descriptor.codepoint) != null) {
            try font.setSize(.{ .points = @bitCast(descriptor.size) });
            return font.*;
        }
    }

    var it = try fat.iterateFonts(self.allocator, .{ .family = "Arial", .codepoint = descriptor.codepoint });
    defer it.deinit();

    while (try it.next()) |deffered_face| {
        defer deffered_face.deinit();

        if (!deffered_face.hasCodepoint(descriptor.codepoint)) {
            continue;
        }

        try self.fonts.append(self.allocator, try deffered_face.open(.{ .size = .{ .points = @bitCast(descriptor.size) } }));
        return self.fonts.getLast();
    }

    return null;
}
