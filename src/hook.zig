const std = @import("std");
const windows = @import("windows.zig");

pub fn testing() !void {
    const dxgi = try windows.GetModuleHandle("dxgi.dll");
    _ = dxgi;
}
