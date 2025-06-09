const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const shared = @import("gui/shared.zig");
const Gui = @import("Gui.zig");
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

pub fn Desc(comptime T: type) type {
    return struct {
        const Error = T;

        frame_cb: *const fn () Error!void,
        cleanup_cb: ?*const fn () void = null,
    };
}

pub const gui = &state.gui;

const state = struct {
    var gui = Gui.init;

    var frame_cb: ?*const fn () anyerror!void = null;
    var cleanup_cb: ?*const fn () void = null;

    var reset_event = Thread.ResetEvent{};

    // Trace is being saved cuz dumping stack trace inside hooked function just craches
    // Even if it would not crash saving trace would be nice so we could combinde our trace with hooked functions one
    var exit_err: ?anyerror = null;
    var exit_err_trace: if (error_tracing) ?std.builtin.StackTrace else void = if (error_tracing) null else {};

    var backend: ?union {
        d3d11: D3D11Backend,
    } = null;
};

fn extractError(comptime FnType: type) type {
    return switch (@typeInfo(FnType)) {
        .@"fn" => |f| return switch (@typeInfo(f.return_type.?)) {
            .error_union => |err_union| err_union.error_set,
            else => @panic("Implement non err set return type"),
        },
        else => @compileError("Expected fn type, found '" ++ @typeName(FnType) ++ "'"),
    };
}

// Idea is simple... Hook everything we can
pub fn run(comptime FnType: type, desc: Desc(extractError(FnType))) !void {
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

        // I want to pass my allocator here
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

    const Error = D3D11Backend.Error || extractError(FnType);
    if (state.exit_err) |err| {
        if (error_tracing) {
            if (state.exit_err_trace) |exit_err_trace| {
                // cant err cuz we used debug_info to save that trace
                // cross fingers that nothing bad happens here
                const debug_info = std.debug.getSelfDebugInfo() catch unreachable;
                const debug_allocator = debug_info.allocator;

                const err_trace = @errorReturnTrace().?;

                err_trace.index = exit_err_trace.index;
                @memcpy(err_trace.instruction_addresses, exit_err_trace.instruction_addresses);

                debug_allocator.free(exit_err_trace.instruction_addresses);
            }
        }

        return @as(Error, @errorCast(err));
    }
}

pub fn unhook() void {
    assert(state.frame_cb != null);
    state.reset_event.set();
}

fn frame(swap_chain: *dxgi.IDXGISwapChain) anyerror!void {
    if (state.backend == null) {
        state.backend = .{ .d3d11 = try D3D11Backend.init(swap_chain) };
    }

    try state.frame_cb.?();

    state.backend.?.d3d11.frame(gui.draw_verticies.constSlice(), gui.draw_indecies.constSlice());
    gui.clear();

}

fn cleanup() void {
    if (state.cleanup_cb) |cleanup_cb| {
        cleanup_cb();
    }

    if (state.backend) |backend| {
        backend.d3d11.deinit();
        state.backend = null;
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
            assert(state.exit_err_trace == null);

            const debug_info = std.debug.getSelfDebugInfo() catch break :blk;
            const debug_allocator = debug_info.allocator;

            if (@errorReturnTrace()) |trace| {
                const instruction_addresses = debug_allocator.dupe(usize, trace.instruction_addresses) catch break :blk;
                state.exit_err_trace = std.builtin.StackTrace{
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
    if (state.reset_event.isSet()) {
        return o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);
    }

    // todo: gui deinit
    state.backend.?.d3d11.deinit();

    // should we check if this hr is even correct like if it issint we just idk unhhok
    const hr = o_resize_buffers(pSwapChain, BufferCount, Width, Height, NewFormat, SwapChainFlags);

    const d3d11_backend = D3D11Backend.init(pSwapChain) catch |err| ret: {
        defer state.reset_event.set();

        cleanup();

        if (error_tracing) blk: {
            assert(state.exit_err_trace == null);

            const debug_info = std.debug.getSelfDebugInfo() catch break :blk;
            const debug_allocator = debug_info.allocator;

            if (@errorReturnTrace()) |trace| {
                const instruction_addresses = debug_allocator.dupe(usize, trace.instruction_addresses) catch break :blk;
                state.exit_err_trace = std.builtin.StackTrace{
                    .instruction_addresses = instruction_addresses,
                    .index = trace.index,
                };
            }
        }

        assert(state.exit_err == null);
        state.exit_err = err;

        break :ret null;
    };

    state.backend = if (d3d11_backend) |backend| .{ .d3d11 = backend } else null;

    return hr;
}
