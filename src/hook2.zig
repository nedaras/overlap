const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

allocator: Allocator,
d3d11_hook: *D3D11Hook,

reset_event_a: Thread.ResetEvent,
reset_event_b: Thread.ResetEvent,

gui: Gui,

const Self = @This();

// todo: just add zelf thingy cuz there should be only one hook tbf
pub fn init(allocator: Allocator) !*Self {
    const window = windows.GetForegroundWindow() orelse return error.NoWindow;

    // kinda stupid ngl
    const result = try allocator.create(Self);
    errdefer allocator.destroy(result);

    try minhook.MH_Initialize();
    errdefer minhook.MH_Uninitialize() catch {};

    var d3d11_hook = try D3D11Hook.init(window, .{
        .frame_cb = &frame,
        .error_cb = &errored,
        .context = result,
    });
    errdefer d3d11_hook.deinit();

    // todo: add like d3d11_hook::wait
    // its like waiting for first present call to make backend object
    // but that backend can become null if resize buffers fails or smth

    while (d3d11_hook.backend == null) {
        std.atomic.spinLoopHint();
    }

    result.* = .{
        .allocator = allocator,
        .d3d11_hook = d3d11_hook,
        .reset_event_a = .{},
        .reset_event_b = .{},
        .gui = Gui.init,
    };

    return result;
}


// todo: rename this like unhook
// and instead of init add like hook func and init will be just Hook{};

pub fn deinit(self: *Self) void {
    self.d3d11_hook.deinit();
    minhook.MH_Uninitialize() catch {};

    self.allocator.destroy(self);
}

pub fn newFrame(self: *Self) void {
    self.reset_event_a.wait();
}

pub fn endFrame(self: *Self) void {
    self.reset_event_a.reset();
    self.reset_event_b.set();
}

// hooked thread
fn errored(context: *anyopaque, err: D3D11Hook.Error) void {
    _ = context;
    err catch unreachable;
}

// hooked thread
fn frame(context: *anyopaque, backend: Backend) bool {
    const self: *Self = @ptrCast(@alignCast(context));

    self.reset_event_a.set();

    self.reset_event_b.wait();
    self.reset_event_b.reset();

    backend.frame(self.gui.draw_verticies.constSlice(), self.gui.draw_indecies.constSlice(), self.gui.draw_commands.constSlice());
    self.gui.clear();

    return true;
}
