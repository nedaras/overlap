const std = @import("std");
const shared = @import("../gui/shared.zig");
const windows = @import("../windows.zig");
const Hook = @import("../Hook.zig");
const assert = std.debug.assert;

window: windows.HWND,
hook: *Hook,

o_wndproc: windows.WNDPROC,

const Self = @This();

var zelf: ?Self = null;

pub fn init(window: windows.HWND, hook: *Hook) !*Self {
    assert(zelf == null);

    const ret = try windows.SetWindowLongPtr(window, windows.GWLP_WNDPROC, @intCast(@intFromPtr(&hkWNDPROC)));
    const o_windproc: windows.WNDPROC = @ptrFromInt(@as(usize, @intCast(ret)));

    zelf = .{
        .window = window,
        .hook = hook,
        .o_wndproc = o_windproc,
    };

    return &zelf.?;
}

pub fn deinit(self: Self) void {
    _ = windows.SetWindowLongPtr(self.window, windows.GWLP_WNDPROC, @intCast(@intFromPtr(self.o_wndproc))) catch {};
    zelf = null;
}

fn hkWNDPROC(
    hWnd: windows.HWND,
    uMsg: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM,
) callconv(.winapi) windows.LRESULT {
    const self = zelf.?;
    const mutex = &self.hook.gateway.mutex;
    const input = &self.hook.gateway.input;

    // tood: make a switch like WM enum or smth

    if (uMsg == windows.WM_MOUSEMOVE) {
        mutex.lock();
        defer mutex.unlock();

        input.mouse_x = @intCast(lParam & 0xFFFF);
        input.mouse_y = @intCast((lParam >> 16) & 0xFFFF);
    }

    if (uMsg == windows.WM_LBUTTONDOWN or uMsg == windows.WM_LBUTTONUP) {
        mutex.lock();
        defer mutex.unlock();

        input.mouse_x = @intCast(lParam & 0xFFFF);
        input.mouse_y = @intCast((lParam >> 16) & 0xFFFF);

        input.mouse_ldown = uMsg == windows.WM_LBUTTONDOWN;
    }

    if (uMsg == windows.WM_RBUTTONDOWN or uMsg == windows.WM_RBUTTONUP) {
        mutex.lock();
        defer mutex.unlock();

        input.mouse_x = @intCast(lParam & 0xFFFF);
        input.mouse_y = @intCast((lParam >> 16) & 0xFFFF);

        input.mouse_rdown = uMsg == windows.WM_RBUTTONDOWN;
    }

    return windows.user32.CallWindowProcA(self.o_wndproc, hWnd, uMsg, wParam, lParam);
}
