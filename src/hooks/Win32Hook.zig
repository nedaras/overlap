const std = @import("std");
const windows = @import("../windows.zig");
const assert = std.debug.assert;

window: windows.HWND,
o_wndproc: windows.WNDPROC,

const Self = @This();

var zelf: ?Self = null;

pub fn init(window: windows.HWND) !*Self {
    assert(zelf == null);

    const ret = try windows.SetWindowLongPtr(window, windows.GWLP_WNDPROC, @intCast(@intFromPtr(&hkWNDPROC)));
    const o_windproc: windows.WNDPROC = @ptrFromInt(@as(usize, @intCast(ret)));

    zelf = .{
        .window = window,
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
) callconv(windows.WINAPI) windows.LRESULT {
    const self = zelf.?;

    if (uMsg == windows.WM_MOUSEMOVE) {
        // todo: fix this for 32 bits
        const x: i16 = @intCast(lParam & 0xFFFF);
        const y: i16 = @intCast((lParam >> 16) & 0xFFFF);

        std.debug.print("{d} {d}\n", .{x, y});
    }

    return windows.user32.CallWindowProcA(self.o_wndproc, hWnd, uMsg, wParam, lParam);
}
