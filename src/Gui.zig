const std = @import("std");
const shared = @import("gui/shared.zig");
const Backend = @import("gui/Backend.zig");
const Image = @import("gui/Image.zig");

// We can have a potential probelm in the future
// What if Directx and Opengl calls frame at the same time
// we can have races to verticies/indecies creations ands destructions
// in my opinion there should only be one backend hooked
const x = 0;
const y = 1;

const DrawCommands = std.BoundedArray(shared.DrawCommand, 32);
const DrawVerticies = std.BoundedArray(shared.DrawVertex, 128);
const DrawIndecies = std.BoundedArray(shared.DrawIndex, 256);

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
    const verticies = [_]shared.DrawVertex{
        .{ .pos = .{ top[x], top[y] }, .uv = .{ 0.0, 0.0 }, .col = 0xFFFFFFFF },
        .{ .pos = .{ bot[x], top[y] }, .uv = .{ 1.0, 0.0 }, .col = 0xFFFFFFFF },
        .{ .pos = .{ bot[x], bot[y] }, .uv = .{ 1.0, 1.0 }, .col = 0xFFFFFFFF },
        .{ .pos = .{ top[x], bot[y] }, .uv = .{ 0.0, 1.0 }, .col = 0xFFFFFFFF },
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

pub fn text(self: *Gui, top: [2]f32, utf8_str: []const u8) void {
    _ = self;
    _ = top;
    _ = utf8_str;
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
    const index_off: u16 = @intCast(self.draw_indecies.len);

    self.draw_verticies.appendSlice(draw_cmd.verticies) catch unreachable;

    for (draw_cmd.indecies) |idx| {
        self.draw_indecies.append(amt + idx) catch unreachable;
    }

    // todo: optimize if curr draw cmd image is same as last draw cmd image
    self.draw_commands.append(.{
        .image = draw_cmd.image,
        .index_len = @intCast(draw_cmd.indecies.len),
        .index_off = index_off, // todo: make backend calc this
    }) catch unreachable;
}

//fn equalImages(a: ?Image, b: ?Image) bool {
    //if (a != null and b != null) {
        //return a.?.ptr == b.?.ptr;
    //}

    //return a == b;
//}
