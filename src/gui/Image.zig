const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{
    OutOfMemory,
    Unexpected,
};

pub const Format = enum(u8) {
    R8G8B8A8_UNORM = 4,
};

pub const Desc = struct {
    width: u32,
    height: u32,
    data: []const u8,
    format: Format,
};

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (*anyopaque) void,
};

const Image = @This();

pub inline fn deinit(self: Image) void {
    self.vtable.deinit(self.ptr);
}
