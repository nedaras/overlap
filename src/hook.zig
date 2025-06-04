const std = @import("std");
const windows = @import("windows.zig");

pub fn testing() !void {
    const dxgi = try windows.GetModuleHandle("dxgi.dll");
    const dxgi_address = @intFromPtr(dxgi);

    std.debug.print("dxgi.dll is at 0x{X}\n", .{dxgi_address});
}
