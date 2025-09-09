const std = @import("std");
const windows = @import("../windows.zig");
const minhook = @import("../minhook.zig");
const Backend = @import("../gui/Backend.zig");
const D3D11Backend = @import("../gui/backends/D3D11Backend.zig");
const mem = std.mem;
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const assert = std.debug.assert;

pub const Error = Backend.Error;

frame_cb: *const fn (context: *anyopaque, backend: Backend) bool,
error_cb: *const fn (context: *anyopaque, err: Error) void,

context: *anyopaque,

present: *const SwapChainPresent,
resize_buffers: *const SwapChainResizeBuffers,

o_present: *SwapChainPresent,
o_resize_buffers: *SwapChainResizeBuffers,

backend: ?D3D11Backend = null,

forward: bool,

const Self = @This();

const SwapChainPresent = @TypeOf(hkPresent);
const SwapChainResizeBuffers = @TypeOf(hkResizeBuffers);

var zelf: ?Self = null;

pub const Desc = struct {
    frame_cb: *const fn (context: *anyopaque, backend: Backend) bool,
    error_cb: *const fn (context: *anyopaque, err: Error) void,
    context: *anyopaque,
};

pub fn init(window: windows.HWND, desc: Desc) !*Self {
    assert(zelf == null);

    const d3d11_lib = try windows.GetModuleHandle("d3d11.dll");

    const D3D11CreateDeviceAndSwapChain = *const @TypeOf(d3d11.D3D11CreateDeviceAndSwapChain);
    const d3d11_create_device_and_swap_chain: D3D11CreateDeviceAndSwapChain = @ptrCast(try windows.GetProcAddress(
        d3d11_lib,
        "D3D11CreateDeviceAndSwapChain",
    ));

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

    const present: *const SwapChainPresent = @ptrCast(swap_chain.vtable[8]);
    const resize_buffers: *const SwapChainResizeBuffers = @ptrCast(swap_chain.vtable[13]);

    var o_present: *SwapChainPresent = undefined;
    var o_resize_buffers: *SwapChainResizeBuffers = undefined;

    try minhook.MH_CreateHook(SwapChainPresent, present, &hkPresent, &o_present);
    errdefer minhook.MH_RemoveHook(SwapChainPresent, present) catch {};

    try minhook.MH_CreateHook(SwapChainResizeBuffers, resize_buffers, &hkResizeBuffers, &o_resize_buffers);
    errdefer minhook.MH_RemoveHook(SwapChainResizeBuffers, resize_buffers) catch {};

    zelf = Self{
        .frame_cb = desc.frame_cb,
        .error_cb = desc.error_cb,
        .context = desc.context,
        .present = present,
        .resize_buffers = resize_buffers,
        .o_present = o_present,
        .o_resize_buffers = o_resize_buffers,
        .forward = true,
    };

    try minhook.MH_EnableHook(SwapChainPresent, present);
    errdefer minhook.MH_DisableHook(SwapChainPresent, present) catch {};

    try minhook.MH_EnableHook(SwapChainResizeBuffers, resize_buffers);
    errdefer minhook.MH_DisableHook(SwapChainResizeBuffers, resize_buffers) catch {};

    return &zelf.?;
}

pub fn deinit(self: *Self) void {
    minhook.MH_DisableHook(SwapChainPresent, self.present) catch {};
    minhook.MH_DisableHook(SwapChainResizeBuffers, self.resize_buffers) catch {};

    minhook.MH_RemoveHook(SwapChainPresent, self.present) catch {};
    minhook.MH_RemoveHook(SwapChainResizeBuffers, self.resize_buffers) catch {};

    if (self.backend) |backend| {
        backend.deinit();
        self.backend = null;
    }

    self.* = undefined;
    zelf = null;
}

fn hkPresent(
    pSwapChain: *dxgi.IDXGISwapChain,
    SyncInterval: windows.UINT,
    Flags: windows.UINT,
) callconv(.winapi) windows.HRESULT {
    var self = &zelf.?;
    if (self.forward) blk: {
        if (self.backend == null) {
            self.backend = D3D11Backend.init(pSwapChain) catch |err| {
                self.forward = false;
                self.error_cb(self.context, err);

                break :blk;
            };
        }

        const backend = self.backend.?.backend();
        if (!self.frame_cb(self.context, backend)) {
            self.forward = false;
        }
    }

    return self.o_present(pSwapChain, SyncInterval, Flags);
}

fn hkResizeBuffers(
    pSwapChain: *dxgi.IDXGISwapChain,
    BufferCount: windows.UINT,
    Width: windows.UINT,
    Height: windows.UINT,
    NewFormat: dxgi.DXGI_FORMAT,
    SwapChainFlags: windows.UINT,
) callconv(.winapi) windows.HRESULT {
    var self = &zelf.?;
    if (!self.forward) {
        return self.o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);
    }

    if (self.backend) |backend| {
        backend.deinit();
        self.backend = null;
    }

    const hr = self.o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);

    self.backend = D3D11Backend.init(pSwapChain) catch |err| blk: {
        self.forward = false;
        self.error_cb(self.context, err);
        break :blk null;
    };

    return hr;
}
