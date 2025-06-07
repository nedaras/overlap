const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const D3D11Backend = @import("gui/backends/D3D11Backend.zig");
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;
const atomic = std.atomic;
const mem = std.mem;
const Thread = std.Thread;
const assert = std.debug.assert;
const error_tracing = std.posix.unexpected_error_tracing;

pub const Gui = @import("Gui.zig");

const Desc = struct {
    frame_cb: *const fn (gui: Gui) error{Testing}!void,
    cleanup_cb: ?*const fn () void = null,
};

const ExitError = D3D11Backend.Error || error{Testing};

const state = struct {
    var frame_cb: ?*const fn (gui: Gui) error{Testing}!void = null;
    var cleanup_cb: ?*const fn () void = null;

    var reset_event = Thread.ResetEvent{};

    var exit_err: ?ExitError = undefined;
    var exit_trace: if (error_tracing) ?std.builtin.StackTrace else void = if (error_tracing) null else {};

    var d3d11_backend: ?D3D11Backend = null;
};

// Idea is simple... Hook everything we can
pub fn run(desc: Desc) !void {
    assert(state.frame_cb == null);

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

    {

        const present: *const SwapChainPresent = @ptrCast(swap_chain.vtable[8]);
        const resize_buffers: *const SwapChainResizeBuffers = @ptrCast(swap_chain.vtable[13]);

        try minhook.MH_Initialize();
        defer minhook.MH_Uninitialize() catch {};

        try minhook.MH_CreateHook(SwapChainPresent, present, &hkPresent, &o_present);
        defer minhook.MH_RemoveHook(SwapChainPresent, present) catch {};

        try minhook.MH_CreateHook(SwapChainResizeBuffers, resize_buffers, &hkResizeBuffers, &o_resize_buffers);
        defer minhook.MH_RemoveHook(SwapChainResizeBuffers, resize_buffers) catch {};

        state.frame_cb = desc.frame_cb;
        state.cleanup_cb = desc.cleanup_cb;

        try minhook.MH_EnableHook(SwapChainPresent, present);
        defer minhook.MH_DisableHook(SwapChainPresent, present) catch {};

        try minhook.MH_EnableHook(SwapChainResizeBuffers, resize_buffers);
        defer minhook.MH_DisableHook(SwapChainResizeBuffers, resize_buffers) catch {};

        state.reset_event.wait();
    }


    if (state.exit_err) |err| {
        std.debug.print("$1error: {s}\n", .{@errorName(err)});
        if (error_tracing) {
            if (state.exit_trace) |trace| {
                std.debug.dumpStackTrace(trace);

                // cant err cuz we used debug_info to save that trace
                const debug_info = std.debug.getSelfDebugInfo() catch unreachable;
                const debug_allocator = debug_info.allocator;

                debug_allocator.free(trace.instruction_addresses);
            }
        }

        return err;
    }
}

pub fn unhook() void {
    assert(state.frame_cb != null);
    state.reset_event.set();
}

fn frame(swap_chain: *dxgi.IDXGISwapChain) !void {
    if (state.d3d11_backend == null) {
        state.d3d11_backend = try D3D11Backend.init(swap_chain);
    }

    const backend = state.d3d11_backend.?.backend();
    defer backend.frame();

    try state.frame_cb.?(Gui{ .backend = backend });
}

fn cleanup() void {
    if (state.cleanup_cb) |cleanup_cb| {
        cleanup_cb();
    }

    if (state.d3d11_backend) |*backend| {
        backend.deinit();
    }
}

const SwapChainPresent = @TypeOf(hkPresent);
const SwapChainResizeBuffers = @TypeOf(hkResizeBuffers);

var o_present: *SwapChainPresent = undefined;
var o_resize_buffers: *SwapChainResizeBuffers = undefined;

fn hkPresent(pSwapChain: *dxgi.IDXGISwapChain, SyncInterval: windows.UINT, Flags: windows.UINT) callconv(windows.WINAPI) windows.HRESULT {
    // potential err is if for some reason there is mulitple active swap chains
    // we prob could check if swap_chain pointers matches or smth
    const exiting = state.reset_event.impl.state.load(.monotonic) == 2; // Bit faster
    if (!exiting) frame(pSwapChain) catch |err| {
        defer state.reset_event.set();

        cleanup();

        if (error_tracing) blk: {
            assert(state.exit_trace == null);

            const debug_info = std.debug.getSelfDebugInfo() catch break :blk;
            const debug_allocator = debug_info.allocator;

            if (@errorReturnTrace()) |trace| {
                const instruction_addresses = debug_allocator.dupe(usize, trace.instruction_addresses) catch break: blk;
                state.exit_trace = std.builtin.StackTrace{
                    .instruction_addresses = instruction_addresses,
                    .index = trace.index,
                };
            }
        }

        assert(state.exit_err == null);
        state.exit_err = err;
    };

    return o_present(pSwapChain, SyncInterval, Flags);
}

fn hkResizeBuffers(pSwapChain: *dxgi.IDXGISwapChain, BufferCount: windows.UINT, Width: windows.UINT, Height: windows.UINT, NewFormat: dxgi.DXGI_FORMAT, SwapChainFlags: windows.UINT) callconv(windows.WINAPI) windows.HRESULT {
    if (state.reset_event.isSet() or state.d3d11_backend == null) {
        return o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);
    }

    state.d3d11_backend.?.deinit();
    const hr = o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);
    state.d3d11_backend = D3D11Backend.init(pSwapChain) catch unreachable;

    return hr;
}
