const std = @import("std");
const set = @import("set");
const windows = @import("../windows.zig");
const detours = @import("../detours.zig");
const Hooks = @import("../Hooks.zig");
const graphics = @import("../graphics.zig");

const d3d11 = windows.d3d11;
const dxgi = windows.dxgi;
const d3dcommon = windows.d3dcommon;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

handle: *Hooks,

//release: *@TypeOf(Release),
present: *@TypeOf(Present),
resize_buffers: *@TypeOf(ResizeBuffers),

const Hook = @This();

var global: ?Hook = null;

pub fn attach(d3d11_lib: windows.HMODULE, handle: *Hooks, window: windows.HWND) !void {
    if (global != null) {
        return error.AlreadyHooked;
    }

    const D3D11CreateDeviceAndSwapChain = *const @TypeOf(d3d11.D3D11CreateDeviceAndSwapChain);
    const d3d11_create_device_and_swap_chain: D3D11CreateDeviceAndSwapChain = @ptrCast(try windows.GetProcAddress(
        d3d11_lib,
        "D3D11CreateDeviceAndSwapChain",
    ));

    var sd = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
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

    const hr = d3d11_create_device_and_swap_chain(
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

    switch (d3d11.D3D11_ERROR_CODE(hr)) {
        .S_OK => {},
        else => |err| return d3d11.unexpectedError(err),
    }

    defer swap_chain.Release();
    defer device.Release();
    defer device_context.Release();

    var present: *@TypeOf(Present) = @constCast(@ptrCast(swap_chain.vtable[8]));
    var resize_buffers: *@TypeOf(ResizeBuffers) = @constCast(@ptrCast(swap_chain.vtable[13]));

    try detours.attach(Present, &present);
    errdefer detours.detach(Present, &present) catch {};

    try detours.attach(ResizeBuffers, &resize_buffers);
    errdefer detours.detach(ResizeBuffers, &resize_buffers) catch {};

    global = .{
        .handle = handle,
        .present = present,
        .resize_buffers = resize_buffers,
    };
}

pub fn detach() void {
    if (global != null) {
        detours.detach(Present, &global.?.present) catch {};
        detours.detach(ResizeBuffers, &global.?.resize_buffers) catch {};
    }
}

fn Release(pIUnknown: *windows.IUnknown) callconv(.winapi) windows.ULONG {
    const refs = global.?.release(pIUnknown);
    return refs;
}

fn Present(
    pSwapChain: *dxgi.IDXGISwapChain,
    SyncInterval: windows.UINT,
    Flags: windows.UINT,
) callconv(.winapi) windows.HRESULT {
    global.?.handle.mutex.lock();
    defer global.?.handle.mutex.unlock();

    const device = graphics.d3d11.Device.init(pSwapChain) catch |err| {
        std.log.err("could not init d3d11 device: {}", .{err});
        return global.?.present(pSwapChain, SyncInterval, Flags);
    };
    defer device.deinit();

    const Gui = @import("../Gui2.zig");
    var gui: Gui = .init;

    Hooks.test_(&gui);

    device.render(gui.draw_verticies.slice(), gui.draw_indecies.slice(), gui.draw_commands.slice()) catch |err| {
        std.log.err("could not render d3d11 device: {}", .{err});
        return global.?.present(pSwapChain, SyncInterval, Flags);
    };

    return global.?.present(pSwapChain, SyncInterval, Flags);
}

fn ResizeBuffers(
    pSwapChain: *dxgi.IDXGISwapChain,
    BufferCount: windows.UINT,
    Width: windows.UINT,
    Height: windows.UINT,
    NewFormat: dxgi.DXGI_FORMAT,
    SwapChainFlags: windows.UINT,
) callconv(.winapi) windows.HRESULT {
    const hr = global.?.resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);
    return hr;
}
