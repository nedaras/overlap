const std = @import("std");
const windows = @import("windows.zig");
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const mem = std.mem;

pub fn testing() !void {
    _ = try windows.GetModuleHandle("d3d11.dll");
    const window = windows.GetForegroundWindow() orelse return error.NoWindow;

    var sd = mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
    sd.BufferCount = 1;
    sd.BufferDesc.Format = dxgi.DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.OutputWindow = window;
    sd.SampleDesc.Count = 1;
    sd.Windowed = windows.TRUE;
    sd.SwapEffect = dxgi.DXGI_SWAP_EFFECT_DISCARD;


    const feature_levels = [_]d3dcommon.D3D_FEATURE_LEVEL{
        d3dcommon.D3D_FEATURE_LEVEL_11_0,
        d3dcommon.D3D_FEATURE_LEVEL_10_1,
        d3dcommon.D3D_FEATURE_LEVEL_10_0,
    };

    var swap_chain: *dxgi.IDXGISwapChain = undefined;
    const result = d3d11.D3D11CreateDeviceAndSwapChain(
        null,
        d3dcommon.D3D_DRIVER_TYPE_HARDWARE,
        null,
        0,
        &feature_levels,
        feature_levels.len,
        d3d11.D3D11_SDK_VERSION,
        &sd,
        &swap_chain,
        null,
        null,
        null,
    );


    // need to release them
    std.debug.print("{} {}\n", .{result, windows.S_OK});
    std.debug.print("ref_count: {d}\n", .{swap_chain.Release()});
}
