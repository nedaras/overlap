const std = @import("std");
const windows = @import("windows.zig");
const graphics = @import("graphics.zig");
const d3d11 = @import("hooks/d3d11.zig");
const Gui = @import("Gui2.zig");

const Mutex = std.Thread.Mutex;

const Hooks = @This();

mutex: Mutex,

pub const init: Hooks = .{
    .mutex = .{},
};

pub const Backend = union(enum) {
    d3d11: windows.HMODULE,
};

pub fn attach(hooks: *Hooks, backend: Backend) !void {
    const window = try windows.CreateWindowEx(
        0,
        "STATIC",
        "Overlap DXGI Window",
        windows.WS_OVERLAPPEDWINDOW,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        640,
        480,
        null,
        null,
        null,
        null,
    );
    defer windows.DestroyWindow(window);

    return switch (backend) {
        .d3d11 => |lib| d3d11.attach(lib, hooks, window),
    };
}

pub fn deinit(hooks: *Hooks) void {
    d3d11.detach();
    hooks.* = undefined;
}
