const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;

d3d11_hook: ?*D3D11Hook = null,

reset_event_a: Thread.ResetEvent = .{},
reset_event_b: Thread.ResetEvent = .{},

gui: Gui = .init,
exiting: bool = false,

const Self = @This();

// todo: just add zelf thingy cuz there should be only one hook tbf
pub fn attach(self: *Self) !void {
    const window = windows.GetForegroundWindow() orelse return error.NoWindow;

    try minhook.MH_Initialize();
    errdefer minhook.MH_Uninitialize() catch {};

    var d3d11_hook = try D3D11Hook.init(window, .{
        .frame_cb = &frame,
        .error_cb = &errored,
        .context = self,
    });
    errdefer d3d11_hook.deinit();

    // tood: put into wait or smth idk
    while (self.d3d11_hook == null) {
        @branchHint(.cold);
        std.atomic.spinLoopHint();
    }

    self.d3d11_hook = d3d11_hook;
}

pub fn detach(self: *Self) void {
    self.exiting = true;
    self.reset_event_b.set();

    self.d3d11_hook.?.deinit();
    minhook.MH_Uninitialize() catch {};
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
// if false is returned frame will never be called again
fn frame(context: *anyopaque, backend: Backend) bool {
    const self: *Self = @ptrCast(@alignCast(context));

    self.reset_event_a.set();

    // now it waits even if we unhook cuz noone resets it
    self.reset_event_b.wait();
    self.reset_event_b.reset();

    if (self.exiting) {
        return false;
    }

    backend.frame(self.gui.draw_verticies.constSlice(), self.gui.draw_indecies.constSlice(), self.gui.draw_commands.constSlice());
    self.gui.clear();

    return true;
}
