const std = @import("std");
const fat = @import("fat");
const shared = @import("gui/shared.zig");
const Backend = @import("gui/Backend.zig");
const Image = @import("gui/Image.zig");
const FontRenderer = @import("gui/FontRenderer.zig");
const bounded_array = @import("bounded_array.zig");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;

// We can have a potential probelm in the future
// What if Directx and Opengl calls frame at the same time
// we can have races to verticies/indecies creations ands destructions
// in my opinion there should only be one backend hooked
const x = 0;
const y = 1;

const DrawCommands = bounded_array.BoundedArray(shared.DrawCommand, shared.max_draw_commands);
const DrawVerticies = bounded_array.BoundedArray(shared.DrawVertex, shared.max_verticies);
const DrawIndecies = bounded_array.BoundedArray(shared.DrawIndex, shared.max_indicies);

allocator: Allocator,

draw_commands: DrawCommands,

// todo: move text stuff somewhere else
draw_verticies: DrawVerticies,
draw_indecies: DrawIndecies,

font_renderer: FontRenderer,

const Gui = @This();

pub fn init(allocator: Allocator, backend: Backend) !Gui {
    return .{
        .allocator = allocator,
        .draw_commands = .{},
        .draw_verticies = .{},
        .draw_indecies = .{},
        .font_renderer = try FontRenderer.init(allocator, backend),
    };
}

pub fn deinit(self: *Gui) void {
    self.font_renderer.deinit();
}

pub fn rect(self: *Gui, top: [2]f32, bot: [2]f32, col: u32) void {
    const verticies = [_]shared.DrawVertex{
        .{ .pos = .{ top[x], top[y] }, .uv = .{ 0.0, 0.0 }, .col = col },
        .{ .pos = .{ bot[x], top[y] }, .uv = .{ 1.0, 0.0 }, .col = col },
        .{ .pos = .{ bot[x], bot[y] }, .uv = .{ 1.0, 1.0 }, .col = col },
        .{ .pos = .{ top[x], bot[y] }, .uv = .{ 0.0, 1.0 }, .col = col },
    };

    const indecies = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };

    self.addDrawCommand(.{
        .image = null,
        .verticies = &verticies,
        .indecies = &indecies,
    });
}

pub fn image(self: *Gui, top: [2]f32, bot: [2]f32, src: Image) void {
    const flags: u8 = @intFromEnum(src.format);
    const verticies = [_]shared.DrawVertex{
        .{ .pos = .{ top[x], top[y] }, .uv = .{ 0.0, 0.0 }, .col = 0xFFFFFFFF, .flags = flags },
        .{ .pos = .{ bot[x], top[y] }, .uv = .{ 1.0, 0.0 }, .col = 0xFFFFFFFF, .flags = flags },
        .{ .pos = .{ bot[x], bot[y] }, .uv = .{ 1.0, 1.0 }, .col = 0xFFFFFFFF, .flags = flags },
        .{ .pos = .{ top[x], bot[y] }, .uv = .{ 0.0, 1.0 }, .col = 0xFFFFFFFF, .flags = flags },
    };

    const indecies = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };

    self.addDrawCommand(.{
        .image = src,
        .verticies = &verticies,
        .indecies = &indecies,
    });
}

pub const Descriptor = struct {
    size: f32 = 16.0,
};

// this is cursed this is hell
// so we should just have gpu image no need to cpu one
pub fn text(self: *Gui, pos: [2]f32, msg: []const u8, descriptor: Descriptor) !void {
    const view = try unicode.Wtf8View.init(msg);

    var it = view.iterator();
    var advance: f32 = 0.0;

    while (it.nextCodepoint()) |codepoint| {
        // todo: this is just stoopid that zig cant hash f32 so i need todo it my self ok
        const glyph = try self.font_renderer.getGlyph(.{ .size = @bitCast(descriptor.size), .codepoint = codepoint });
        defer advance += @floatFromInt(glyph.metrics.advance_x);

        const top = [2]f32{ pos[x] + @as(f32, @floatFromInt(glyph.metrics.bearing_x)) + advance, pos[y] + @as(f32, @floatFromInt(glyph.metrics.bearing_y)) };
        const bot = [2]f32{ top[x] + @as(f32, @floatFromInt(glyph.width)), top[y] + @as(f32, @floatFromInt(glyph.height)) };

        const verticies = [_]shared.DrawVertex{
            .{ .pos = .{ top[x], top[y] }, .uv = .{ glyph.uv0[x], glyph.uv0[y] }, .col = 0xFFFFFFFF, .flags = 5 },
            .{ .pos = .{ bot[x], top[y] }, .uv = .{ glyph.uv1[x], glyph.uv0[y] }, .col = 0xFFFFFFFF, .flags = 5 },
            .{ .pos = .{ bot[x], bot[y] }, .uv = .{ glyph.uv1[x], glyph.uv1[y] }, .col = 0xFFFFFFFF, .flags = 5 },
            .{ .pos = .{ top[x], bot[y] }, .uv = .{ glyph.uv0[x], glyph.uv1[y] }, .col = 0xFFFFFFFF, .flags = 5 },
        };

        const indecies = [_]u16{
            0, 1, 2,
            0, 2, 3,
        };

        self.addDrawCommand(.{
            .image = self.font_renderer.atlas.image,
            .verticies = &verticies,
            .indecies = &indecies,
        });
    }
}

pub fn clear(self: *Gui) void {
    self.draw_commands.clear();
    self.draw_verticies.clear();
    self.draw_indecies.clear();
}

const DrawCommand = struct {
    image: ?Image,
    verticies: []const shared.DrawVertex,
    indecies: []const u16,
};

// todo: on debug we can check if indecie are like in bounds
fn addDrawCommand(self: *Gui, draw_cmd: DrawCommand) void {
    const amt: u16 = @intCast(self.draw_verticies.len);

    self.draw_verticies.ensureUnusedCapacity(draw_cmd.verticies.len) catch return;
    self.draw_indecies.ensureUnusedCapacity(draw_cmd.indecies.len) catch return;

    const reuse_image = blk: {
        if (self.draw_commands.len == 0) break :blk false;
        const last_draw_cmd = self.draw_commands.get(self.draw_commands.len - 1);
        break :blk equalImages(last_draw_cmd.image, draw_cmd.image);
    };

    if (reuse_image) {
        self.draw_commands.ensureUnusedCapacity(1) catch return;
    }

    self.draw_verticies.appendSliceAssumeCapacity(draw_cmd.verticies);

    for (draw_cmd.indecies) |idx| {
        // todo: add simd
        // appendSlice
        // and then in simd add do it amt
        self.draw_indecies.appendAssumeCapacity(amt + idx);
    }

    if (reuse_image) {
        const last_draw_cmd = &self.draw_commands.slice()[self.draw_commands.len - 1];
        last_draw_cmd.index_len += @intCast(draw_cmd.indecies.len);

        return;
    }

    self.draw_commands.appendAssumeCapacity(.{
        .image = draw_cmd.image,
        .index_len = @intCast(draw_cmd.indecies.len),
    });
}

fn equalImages(a: ?Image, b: ?Image) bool {
    if (a != null and b != null) {
        return a.?.ptr == b.?.ptr;
    }

    return a == null and b == null;
}
