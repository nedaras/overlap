const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const shared = @import("gui/shared.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
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

    //var hook: ?union {
        //d3d11: *const D3D11Hook,
    //} = null;
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

    try minhook.MH_Initialize();
    defer minhook.MH_Uninitialize() catch {};

    var d3d11_hook = try D3D11Hook.init(undefined, .{
        .frame_cb = &frame,
        .error_cb = &errored,
    });
    defer d3d11_hook.deinit();

    state.frame_cb = desc.frame_cb;
    state.cleanup_cb = desc.cleanup_cb;

    state.reset_event.wait();

    const Error = D3D11Hook.Error || extractError(FnType);
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

// main thread
pub fn unhook() void {
    @panic("implement");
    // assert(state.frame_cb != null);
    // state.reset_event.set();
}

// hooked thread
fn errored(err: D3D11Hook.Error) void {
    @panic(@errorName(err));
}

// hooked thread
fn frame(backend: Backend) void {
    state.frame_cb.?() catch @panic("implement");
    backend.frame(gui.draw_verticies.constSlice(), gui.draw_indecies.constSlice());
}
