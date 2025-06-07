const std = @import("std");

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (*anyopaque) void,
    frame: *const fn (*const anyopaque) void,
};

const Backend = @This();

pub inline fn deinit(self: Backend) void {
    self.vtable.deinit(self.ptr);
}

pub inline fn frame(self: Backend) void {
    self.vtable.frame(self.ptr);
}
