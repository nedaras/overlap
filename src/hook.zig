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
        init_cb: ?*const fn () void = null,
        cleanup_cb: ?*const fn () void = null,
    };
}

pub const Image = @import("gui/Image.zig");
pub const gui = &state.gui;

const state = struct {
    var gui = Gui.init;

    var frame_cb: ?*const fn () anyerror!void = null;
    var init_cb: ?*const fn () void = null;
    var cleanup_cb: ?*const fn () void = null;

    var reset_event = Thread.ResetEvent{};

    // Trace is being saved cuz dumping stack trace inside hooked function just craches
    // Even if it would not crash saving trace would be nice so we could combinde our trace with hooked functions one
    var exit_err: ?anyerror = null;
    var exit_err_trace: if (error_tracing) ?std.builtin.StackTrace else void = if (error_tracing) null else {};

    var backend: ?Backend = null;

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

    const window = windows.GetForegroundWindow() orelse return error.NoWindow;

    try minhook.MH_Initialize();
    defer minhook.MH_Uninitialize() catch {};

    state.frame_cb = desc.frame_cb;
    state.init_cb = desc.init_cb;
    state.cleanup_cb = desc.cleanup_cb;

    var d3d11_hook = try D3D11Hook.init(window, .{
        .frame_cb = &frame,
        .error_cb = &errored,
    });
    defer d3d11_hook.deinit();

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

// hooked thread
pub inline fn loadImage(allocator: mem.Allocator, desc: Image.Desc) Image.Error!Image {
    return state.backend.?.loadImage(allocator, desc);
}

// hooked thread
// todo: cache unhook call cuz till main thead awaiks
//       frame_cb will be called multiple times same as this func
pub fn unhook() void {
    assert(state.frame_cb != null);
    state.reset_event.set();
}

// hooked thread
fn errored(err: anyerror) void {
    assert(state.exit_err == null);

    state.exit_err = err;
    state.reset_event.set();
}

// hooked thread
// we have a problem
// backend::frame can return an error
// what should we do we cant use comptime structs and anyerror is just gross
fn frame(backend: Backend) bool {
    defer gui.clear();

    if (state.backend == null) {
        state.backend = backend;
        if (state.init_cb) |init| init();
    }
    assert(state.backend.?.ptr == backend.ptr);

    state.frame_cb.?() catch |err| {
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
        errored(err);
        return false;
    };

    backend.frame(gui.draw_verticies.constSlice(), gui.draw_indecies.constSlice(), gui.draw_commands.constSlice());
    return true;
}
