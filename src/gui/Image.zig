const std = @import("std");
const Allocator = std.mem.Allocator;

ptr: *const anyopaque,
vtable: *const VImage,

pub const VImage = struct {
    deinit: *const fn (*const anyopaque) void,
};

const Image = @This();

pub inline fn deinit(self: *Image, allocator: Allocator) void {
    self.vtable.deinit(self.ptr);

    allocator.destroy(self);
    self.* = undefined;
}
