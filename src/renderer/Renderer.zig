const std = @import("std");
const shared = @import("../gui/shared.zig");

const Allocator = std.mem.Allocator;
const Renderer = @This();

vtable: *const VTable,

// store vertices here and all

pub const Error = error{
    OutOfMemory,
    Unexpected,
};

pub const VTable = struct {
    deinit: *const fn (*Renderer) void,
    render: *const fn (*Renderer, verticies: []const shared.DrawVertex, indecies: []const u16, draw_commands: []const shared.DrawCommand) Error!void,
};

pub fn deinit(r: *Renderer) void {
    r.vtable.deinit(r);
}

pub fn render(
    r: *Renderer,
    verticies: []const shared.DrawVertex,
    indecies: []const shared.DrawIndex,
    draw_commands: []const shared.DrawCommand,
) Error!void {
    return r.vtable.render(r, verticies, indecies, draw_commands);
}
