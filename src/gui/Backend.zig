const shared = @import("shared.zig");

ptr: *const anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    deinit: *const fn (*const anyopaque) void,
    frame: *const fn (*const anyopaque, verticies: []const shared.DrawVertex, indecies: []const u16) void,
};

const Backend = @This();

pub inline fn deinit(self: Backend) void {
    self.vtable.deinit(self.ptr);
}

pub inline fn frame(self: Backend, verticies: []const shared.DrawVertex, indecies: []const u16) void {
    self.vtable.frame(self.ptr, verticies, indecies);
}
