const std = @import("std");
const windows = @import("windows.zig");
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const mem = std.mem;

const c = @cImport({
    @cInclude("MinHook.h");
});

pub fn testing() !void {
    _ = try windows.GetModuleHandle("d3d11.dll");
    const window = windows.GetForegroundWindow() orelse return error.WindowNotFound;

    var sd = mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
    sd.BufferCount = 1;
    sd.BufferDesc.Format = dxgi.DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.OutputWindow = window;
    sd.SampleDesc.Count = 1;
    sd.Windowed = windows.TRUE;
    sd.SwapEffect = dxgi.DXGI_SWAP_EFFECT_DISCARD;

    var swap_chain: *dxgi.IDXGISwapChain = undefined;

    var device: *d3d11.ID3D11Device = undefined;
    var device_context: *d3d11.ID3D11DeviceContext = undefined;

    const feature_levels = [_]d3dcommon.D3D_FEATURE_LEVEL{
        d3dcommon.D3D_FEATURE_LEVEL_11_0,
        d3dcommon.D3D_FEATURE_LEVEL_10_1,
        d3dcommon.D3D_FEATURE_LEVEL_10_0,
    };

    // mb make nice interface with Unexpected errors
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
        &device,
        null,
        &device_context,
    );

    if (result != windows.S_OK) {
        return error.Unexpected;
    }

    defer swap_chain.Release();
    defer device.Release();
    defer device_context.Release();

    _ = c.MH_Initialize();
    defer _ = c.MH_Initialize();

    _ = c.MH_CreateHook(@constCast(swap_chain.vtable[8]), @constCast(&hkPresent), @ptrCast(&o_present));
    _ = c.MH_EnableHook(@constCast(swap_chain.vtable[8]));
    defer _ = c.MH_DisableHook(c.MH_ALL_HOOKS);

    std.time.sleep(std.time.ns_per_s * 15);

}

var o_present: *@TypeOf(hkPresent) = undefined;
fn hkPresent(pSwapChain: *dxgi.IDXGISwapChain, SyncInterval: windows.UINT, Flags: windows.UINT) callconv(windows.WINAPI) windows.HRESULT {
    std.debug.print("hooked!!!\n", .{});
    return o_present(pSwapChain, SyncInterval, Flags);
}
