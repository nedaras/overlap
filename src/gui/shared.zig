const std = @import("std");

var draw_verticies = std.BoundedArray(DrawVertex, 128).init(0) catch unreachable;
var draw_indecies = std.BoundedArray(u16, 192).init(0) catch unreachable;

pub const DrawCommand = struct {
    verticies: []const DrawVertex,
    indecies: []const u16,
    col: u32,
};

pub const DrawVertex = struct {
    pos: [2]f32,
    col: u32,
};

// todo: on debug we can check if indecie are like in bounds
pub fn addDrawCommand(draw_cmd: DrawCommand) void {
    const amt: u16 = @intCast(draw_verticies.len);

    draw_verticies.appendSlice(draw_cmd.verticies) catch unreachable;

    for (draw_cmd.indecies) |idx| {
        draw_indecies.append(amt + idx) catch unreachable;
    }
}

pub fn verticies() []const DrawVertex {
    return draw_verticies.constSlice();
}

pub fn indecies() []const u16 {
    return draw_indecies.constSlice();
}

pub fn clear() void {
    draw_verticies.clear();
    draw_indecies.clear();
}
