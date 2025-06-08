const std = @import("std");
const shared = @import("gui/shared.zig");
const Backend = @import("gui/Backend.zig");

// We can have a potential probelm in the future
// What if Directx and Opengl calls frame at the same time
// we can have races to verticies/indecies creations ands destructions

const x = 0;
const y = 1;

// idk i think Backend is useless here
// we can store here our indecies verticies and draw cmds
backend: Backend,

const Gui = @This();

pub fn deinit(self: Gui) void {
    self.backend.deinit();
}

// i need to think
pub fn addRectFilled(_: Gui, top: [2]f32, bot: [2]f32, col: u32) void {
    const verticies = [_]shared.DrawVertex{
        .{ .pos = .{ top[x], top[y] }, .col = col },
        .{ .pos = .{ bot[x], top[y] }, .col = col },
        .{ .pos = .{ bot[x], bot[y] }, .col = col },
        .{ .pos = .{ top[x], bot[y] }, .col = col },
    };

    const indecies = [_]u16{
        0, 1, 2,
        0, 2, 3,
    };

    shared.addDrawCommand(.{
        .verticies = &verticies,
        .indecies = &indecies,
        .col = col,
    });
}
