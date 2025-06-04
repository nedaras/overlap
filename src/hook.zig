const std = @import("std");
const windows = @import("windows.zig");

pub fn testing() !void {
    const d3d11 = try windows.GetModuleHandle("d3d11.dll");
    const f = try windows.GetProcAddress(d3d11, "D3D11CreateDeviceAndSwapChain");

    std.debug.print("d3d11.dll is at 0x{X}\n", .{@intFromPtr(d3d11)});
    std.debug.print("D3D11CreateDeviceAndSwapChain is at 0x{X}\n", .{@intFromPtr(f)});
}
