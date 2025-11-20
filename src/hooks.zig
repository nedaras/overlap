const std = @import("std");
const windows = @import("windows.zig");
const d3d11 = @import("hooks/d3d11.zig");

pub const Backend = union(enum) {
    d3d11: windows.HMODULE,
};

var established_hooks: packed struct {
    d3d11: bool = false,
} = .{};

pub fn attach(backend: Backend) !void {
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

    switch (backend) {
        .d3d11 => |lib| if (!established_hooks.d3d11) {
            try d3d11.attach(lib, window);
            established_hooks.d3d11 = true;
        },
    }
}

pub fn detach() void {
    if (established_hooks.d3d11) {
        d3d11.detach();
    }
}
