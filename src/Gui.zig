const std = @import("std");
const shared = @import("gui/shared.zig");
const fat = @import("fat.zig");
const Backend = @import("gui/Backend.zig");
const Image = @import("gui/Image.zig");
const Font = @import("gui/Font.zig");
const Allocator = std.mem.Allocator;

// We can have a potential probelm in the future
// What if Directx and Opengl calls frame at the same time
// we can have races to verticies/indecies creations ands destructions
// in my opinion there should only be one backend hooked
const x = 0;
const y = 1;

const DrawCommands = std.BoundedArray(shared.DrawCommand, shared.max_draw_commands);
const DrawVerticies = std.BoundedArray(shared.DrawVertex, shared.max_verticies);
const DrawIndecies = std.BoundedArray(shared.DrawIndex, shared.max_indicies);

draw_commands: DrawCommands,

draw_verticies: DrawVerticies,
draw_indecies: DrawIndecies,

const Gui = @This();

pub const init = Gui{
    .draw_commands = .{},
    .draw_verticies = .{},
    .draw_indecies = .{},
};

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

pub fn text(self: *Gui, at: [2]f32, utf8_str: []const u8, col: u32, font: Font) void {
    const view = std.unicode.Utf8View.init(utf8_str) catch return;
    var it = view.iterator();

    var advance: f32 = 0.0;
    while (it.nextCodepoint()) |unicode| {
        // todo: if no glyph render the missing char glyph or smth
        const glyph = font.loadGlyph(unicode).?;
        defer advance += glyph.advance;

        // todo: in fat space is not a char for some reason
        if (glyph.size[x] == 0.0 or glyph.size[y] == 0.0) {
            continue;
        }

        const top = [2]f32{
            at[x] + glyph.bearing[x] + advance,
            at[y] + glyph.bearing[y],
        };

        const bot = [2]f32{
            top[x] + glyph.size[x],
            top[y] + glyph.size[y],
        };

        const verticies = [_]shared.DrawVertex{
            .{ .pos = .{ top[x], top[y] }, .uv = .{ glyph.uv_top[x], glyph.uv_top[y] }, .col = col, .flags = 5 },
            .{ .pos = .{ bot[x], top[y] }, .uv = .{ glyph.uv_bot[x], glyph.uv_top[y] }, .col = col, .flags = 5 },
            .{ .pos = .{ bot[x], bot[y] }, .uv = .{ glyph.uv_bot[x], glyph.uv_bot[y] }, .col = col, .flags = 5 },
            .{ .pos = .{ top[x], bot[y] }, .uv = .{ glyph.uv_top[x], glyph.uv_bot[y] }, .col = col, .flags = 5 },
        };

        const indecies = &[_]u16{
            0, 1, 2,
            0, 2, 3,
        };

        self.addDrawCommand(.{
            .image = font.image,
            .verticies = &verticies,
            .indecies = indecies,
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

    self.draw_verticies.appendSlice(draw_cmd.verticies) catch unreachable;

    for (draw_cmd.indecies) |idx| {
        // todo: add simd
        // appendSlice
        // and then in simd add do it amt
        self.draw_indecies.append(amt + idx) catch unreachable;
    }

    if (self.draw_commands.len > 0) blk: {
        const last_draw_cmd = &self.draw_commands.slice()[self.draw_commands.len - 1];
        if (!equalImages(last_draw_cmd.image, draw_cmd.image)) break :blk;

        last_draw_cmd.index_len += @intCast(draw_cmd.indecies.len);
        return;
    }

    self.draw_commands.append(.{
        .image = draw_cmd.image,
        .index_len = @intCast(draw_cmd.indecies.len),
    }) catch unreachable;
}

fn equalImages(a: ?Image, b: ?Image) bool {
    if (a != null and b != null) {
        return a.?.ptr == b.?.ptr;
    }

    return a == null and b == null;
}
