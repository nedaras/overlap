const std = @import("std");
const shared = @import("gui/shared.zig");
const Backend = @import("gui/Backend.zig");

// We can have a potential probelm in the future
// What if Directx and Opengl calls frame at the same time
// we can have races to verticies/indecies creations ands destructions
// in my opinion there should only be one backend hooked
const x = 0;
const y = 1;

const DrawVerticies = std.BoundedArray(shared.DrawVertex, 128);
const DrawIndecies = std.BoundedArray(shared.DrawIndex, 256);

draw_verticies: DrawVerticies,
draw_indecies: DrawIndecies,

const Gui = @This();

pub const init = Gui{
        .draw_verticies = DrawVerticies.init(0) catch unreachable,
        .draw_indecies = DrawIndecies.init(0) catch unreachable,
};

pub fn addRectFilled(self: *Gui, top: [2]f32, bot: [2]f32, col: u32) void {
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
        .verticies = &verticies,
        .indecies = &indecies,
    });
}

pub fn clear(self: *Gui) void {
    self.draw_verticies.clear();
    self.draw_indecies.clear();
}

const DrawCommand = struct {
    verticies: []const shared.DrawVertex,
    indecies: []const u16,
};

// todo: on debug we can check if indecie are like in bounds
fn addDrawCommand(self: *Gui, draw_cmd: DrawCommand) void {
    const amt: u16 = @intCast(self.draw_verticies.len);

    self.draw_verticies.appendSlice(draw_cmd.verticies) catch unreachable;

    for (draw_cmd.indecies) |idx| {
        self.draw_indecies.append(amt + idx) catch unreachable;
    }
}
