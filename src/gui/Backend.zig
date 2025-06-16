const std = @import("std");
const shared = @import("shared.zig");
const Image = @import("Image.zig");
const Allocator = std.mem.Allocator;

ptr: *const anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
    frame: *const fn (*const anyopaque, verticies: []const shared.DrawVertex, indecies: []const u16) void,
    loadImage: *const fn (*const anyopaque, allocator: Allocator, desc: Image.Desc) Image.Error!Image,
};

const Backend = @This();

pub inline fn deinit(self: Backend) void {
    self.vtable.deinit(self.ptr);
}

pub inline fn frame(self: Backend, verticies: []const shared.DrawVertex, indecies: []const u16) void {
    self.vtable.frame(self.ptr, verticies, indecies);
}

pub inline fn loadImage(self: Backend, allocator: Allocator, desc: Image.Desc) Image.Error!Image {
    return self.vtable.loadImage(self.ptr, allocator, desc);
}
