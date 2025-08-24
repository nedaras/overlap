const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;

// todo: add backend here so we could do like image.map -> unmap and stuff without our backend

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
    update: *const fn (*anyopaque, bytes: []const u8, pitch: u32) Error!void,
};

const Image = @This();

pub inline fn deinit(self: Image, allocator: Allocator) void {
    self.vtable.deinit(self.ptr, allocator);
}

pub inline fn update(self: Image, bytes: []const u8) Error!void {
    assert(self.width * self.height * @intFromEnum(self.format) == bytes.len);
    return self.vtable.update(self.ptr, bytes, self.width * @intFromEnum(self.format));
}
