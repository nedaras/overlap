const std = @import("std");
const shared = @import("shared.zig");
const Image = @import("Image.zig");
const Allocator = std.mem.Allocator;

ptr: *const anyopaque,
vtable: *const VTable,

pub const Error = error{
    OutOfMemory,
    Unexpected,
};

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
    frame: *const fn (*const anyopaque, verticies: []const shared.DrawVertex, indecies: []const u16, draw_commands: []const shared.DrawCommand) Error!void,
    loadImage: *const fn (*const anyopaque, allocator: Allocator, desc: Image.Desc) Image.Error!Image,
    updateImage: *const fn (*const anyopaque, image: Image, bytes: []const u8) Error!void,
};

const Backend = @This();

pub inline fn deinit(self: Backend) void {
    self.vtable.deinit(self.ptr);
}

pub inline fn frame(self: Backend, verticies: []const shared.DrawVertex, indecies: []const u16, draw_commands: []const shared.DrawCommand) Error!void {
    return self.vtable.frame(self.ptr, verticies, indecies, draw_commands);
}

pub inline fn loadImage(self: Backend, allocator: Allocator, desc: Image.Desc) Image.Error!Image {
    return self.vtable.loadImage(self.ptr, allocator, desc);
}

pub inline fn updateImage(self: Backend, image: Image, bytes: []const u8) Error!void {
    return self.vtable.updateImage(self.ptr, image, bytes);
}
