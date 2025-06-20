const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
const Thread = std.Thread;

var reset_event_a = Thread.ResetEvent{};
var reset_event_b = Thread.ResetEvent{};

pub var gui = Gui.init;

d3d11_hook: *D3D11Hook,

const Self = @This();

pub fn init() !Self {
    const window = windows.GetForegroundWindow() orelse return error.NoWindow;

    try minhook.MH_Initialize();
    errdefer minhook.MH_Uninitialize() catch {};

    var d3d11_hook = try D3D11Hook.init(window, .{
        .frame_cb = &frame,
        .error_cb = &errored,
    });
    errdefer d3d11_hook.deinit();

    return .{
        .d3d11_hook = d3d11_hook,
    };
}

pub fn deinit(self: *Self) void {
    self.d3d11_hook.deinit();
    minhook.MH_Uninitialize() catch {};
}

pub fn wait(self: *Self) void {
    _ = self;

    reset_event_a.wait();
}

pub fn done(self: *Self) void {
    _ = self;

    reset_event_a.reset();
    reset_event_b.set();
}

// hook thread
fn errored(err: D3D11Hook.Error) void {
    err catch unreachable;
}

// think i way to like pass Self into frame func this state stuff kinda sucks
// hook thread
fn frame(backend: Backend) bool {
    reset_event_a.set();

    reset_event_b.wait();
    reset_event_b.reset();

    backend.frame(gui.draw_verticies.constSlice(), gui.draw_indecies.constSlice(), gui.draw_commands.constSlice());
    gui.clear();

    return true;
}
