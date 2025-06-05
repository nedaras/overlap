const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const Surface = @import("Surface.zig");
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;
const mem = std.mem;
const Thread = std.Thread;

// keep in mind all this is not so thread safe
var mutex = Thread.Mutex.Recursive.init;
var exit_err: ?FrameError = null;

const SwapChainPresent = @TypeOf(hkPresent);
const SwapChainResizeBuffers = @TypeOf(hkResizeBuffers);

var o_present: *SwapChainPresent = undefined;
var o_resize_buffers: *SwapChainResizeBuffers = undefined;

// Idea is simple... Hook everything we can
pub fn testing() !void {
    const d3d11_lib = try windows.GetModuleHandle("d3d11.dll");

    const D3D11CreateDeviceAndSwapChain = *const @TypeOf(d3d11.D3D11CreateDeviceAndSwapChain);
    const d3d11_create_device_and_swap_chain: D3D11CreateDeviceAndSwapChain = @ptrCast(try windows.GetProcAddress(
        d3d11_lib,
        "D3D11CreateDeviceAndSwapChain",
    ));
    
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

    // todo: mb make nice interface with Unexpected errors
    const result = d3d11_create_device_and_swap_chain(
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

    const present: *const SwapChainPresent = @ptrCast(swap_chain.vtable[8]);
    const resize_buffers: *const SwapChainResizeBuffers = @ptrCast(swap_chain.vtable[13]);

    const surface = try Surface.init(device);
    defer surface.deinit();

    try minhook.MH_Initialize();
    defer minhook.MH_Uninitialize() catch {};

    try minhook.MH_CreateHook(SwapChainPresent, present, &hkPresent, &o_present);
    try minhook.MH_CreateHook(SwapChainResizeBuffers, resize_buffers, &hkResizeBuffers, &o_resize_buffers);

    try minhook.MH_EnableHook(SwapChainPresent, present);
    defer minhook.MH_DisableHook(SwapChainPresent, present) catch {};

    try minhook.MH_EnableHook(SwapChainResizeBuffers, resize_buffers);
    defer minhook.MH_DisableHook(SwapChainResizeBuffers, resize_buffers) catch {};

    while (true) {
        Thread.yield() catch unreachable;

        mutex.lock();
        defer mutex.unlock();

        if (exit_err) |err| {
            return err;
        }
    }
}

var exiting = false;

fn hkPresent(
    pSwapChain: *dxgi.IDXGISwapChain,
    SyncInterval: windows.UINT,
    Flags: windows.UINT
) callconv(windows.WINAPI) windows.HRESULT {
    // mb would be better to get device and context from this swap_chain
    // and then init the Surface object

    if (!exiting) frame(pSwapChain) catch |err| {
        exiting = true;

        // stack trace crashes here idk why prob cuz trampoline  hooking by minhook
        //if (@errorReturnTrace()) |trace| {
        // trace here just makes no sence
        //}

        mutex.lock();
        defer mutex.unlock();

        exit_err = err;
    };

    return o_present(pSwapChain, SyncInterval, Flags);
}

fn hkResizeBuffers(
    pSwapChain: *dxgi.IDXGISwapChain,
    BufferCount: windows.UINT,
    Width: windows.UINT,
    Height: windows.UINT,
    NewFormat: dxgi.DXGI_FORMAT,
    SwapChainFlags: windows.UINT
) callconv(windows.WINAPI) windows.HRESULT {
    return o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);
}

const FrameError = @typeInfo(@typeInfo(@TypeOf(frame)).@"fn".return_type.?).error_union.error_set;

fn frame(swap_chain: *dxgi.IDXGISwapChain) !void {
    _ = swap_chain;
    return error.Panic;
}
