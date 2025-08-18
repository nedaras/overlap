const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const shared = @import("gui/shared.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
const Win32Hook = @import("hooks/Win32Hook.zig");
pub const Image = @import("gui/Image.zig");
const mem = std.mem;
const fs = std.fs;
const Thread = std.Thread;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

// todo: fix some race conditions

const Gateway = struct {
    gui: Gui,

    input: shared.Input = .{},
    mutex: Thread.Mutex = .{},

    main_reset_event: Thread.ResetEvent,
    hooked_reset_event: Thread.ResetEvent,

    err: ?FrameError,
    exiting: bool,
};

d3d11_hook: ?*D3D11Hook = null,
win32_hook: ?*Win32Hook = null,

gateway: Gateway,

const Self = @This();

pub fn init() !Self {
    return .{
        .d3d11_hook = null,
        .gateway = .{
            .gui = undefined,
            .main_reset_event = .{},
            .hooked_reset_event = .{},
            .err = null,
            .exiting = false,
        }
    };
}

pub fn deinit(self: *Self) void {
    _ = self;
}

pub fn attach(self: *Self, allocator: Allocator) !void {
    const window = windows.FindWindow(null, "...") orelse return error.NoWindow;

    try minhook.MH_Initialize();
    errdefer minhook.MH_Uninitialize() catch {};

    // todo: move d3d11_hook and all other win32 gfx hooks to win32hook
    const win32_hook = try Win32Hook.init(window, self);
    errdefer win32_hook.deinit();

    var d3d11_hook = try D3D11Hook.init(window, .{
        .frame_cb = &frame,
        .error_cb = &errored,
        .context = self,
    });
    errdefer d3d11_hook.deinit();

    self.gateway.main_reset_event.wait();
    if (self.gateway.err) |err| {
        @branchHint(.cold);
        return err;
    }
    assert(d3d11_hook.backend != null);

    self.d3d11_hook = d3d11_hook;
    self.win32_hook = win32_hook;

    self.gateway.gui = try Gui.init(allocator, d3d11_hook.backend.?.backend());
}

pub fn detach(self: *Self) void {
    self.gateway.exiting = true;
    self.gateway.hooked_reset_event.set();

    self.gateway.gui.deinit();

    if (self.d3d11_hook) |d3d11_hook| {
        d3d11_hook.deinit();
        self.d3d11_hook = null;
    }

    if (self.win32_hook) |win32_hook| {
        win32_hook.deinit();
        self.win32_hook = null;
    }

    minhook.MH_Uninitialize() catch {};
}

pub inline fn gui(self: *Self) *Gui {
    return &self.gateway.gui;
}

pub inline fn input(self: *Self) *shared.Input {
    return &self.gateway.input;
}

pub const FrameError = D3D11Hook.Error;

pub fn newFrame(self: *Self) FrameError!void {
    self.gateway.main_reset_event.wait(); // input mutex
    if (self.gateway.err) |err| {
        @branchHint(.cold);
        return err;
    }
    self.gateway.mutex.lock();
}

pub fn endFrame(self: *Self) void {
    self.gateway.mutex.unlock(); // todo: input mutex and this is dumb af why should windproc wait fot present?
    //       just copy the input to temp input that would be used in present func
    self.gateway.main_reset_event.reset();
    self.gateway.hooked_reset_event.set();
}

pub inline fn loadImage(self: *Self, allocator: Allocator, desc: Image.Desc) Image.Error!Image {
    // todo: idk???
    return self.d3d11_hook.?.backend.?.backend().loadImage(allocator, desc);
}

pub inline fn updateImage(self: *Self, image: Image, bytes: []const u8) Backend.Error!void {
    // todo: idk???
    return self.d3d11_hook.?.backend.?.backend().updateImage(image, bytes);
}

// hooked thread
// only after this call backend becomes invalid
fn errored(context: *anyopaque, err: D3D11Hook.Error) void {
    const self: *Self = @ptrCast(@alignCast(context));

    assert(self.gateway.err == null);

    self.gateway.err = err;
    self.gateway.main_reset_event.set();
}

// hooked thread
// if false is returned frame will never be called again
// ok this backend is kinda useless, cuz it should never be null
// and it is null only if resize buffers fails, if so errored gets called that would mean that yee backend will be invalid!!
// and we should return error anyway sooo idk
fn frame(context: *anyopaque, backend: Backend) bool {
    const self: *Self = @ptrCast(@alignCast(context));

    assert(self.gateway.err == null);
    self.gateway.main_reset_event.set();

    self.gateway.hooked_reset_event.wait();
    self.gateway.hooked_reset_event.reset();

    if (self.gateway.exiting) {
        return false;
    }

    const shared_gui = self.gui();
    defer shared_gui.clear();

    backend.frame(
        shared_gui.draw_verticies.constSlice(),
        shared_gui.draw_indecies.constSlice(),
        shared_gui.draw_commands.constSlice(),
    ) catch |err| {
        errored(context, err);
        return false;
    };

    return true;
}
