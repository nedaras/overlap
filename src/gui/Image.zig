const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{
    OutOfMemory,
    Unexpected,
};

pub const Format = enum(u4) {
    r = 1,
    rgba = 4,
};

pub const Usage = enum(u4) {
    static,
    dynamic,
};

pub const Desc = struct {
    width: u32,
    height: u32,
    data: []const u8,
    format: Format,
    usage: Usage = .static,
};

ptr: *anyopaque,
vtable: *const VTable,

width: u32,
height: u32,

format: Format,

pub const VTable = struct {
    deinit: *const fn (*anyopaque, allocator: Allocator) void,
};

const Image = @This();

pub inline fn deinit(self: Image, allocator: Allocator) void {
    self.vtable.deinit(self.ptr, allocator);
}
