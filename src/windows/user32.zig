const std = @import("std");
const windows = std.os.windows;

const HWND = windows.HWND;
const BOOL = windows.BOOL;
const WINAPI = windows.WINAPI;
const LPRECT = *windows.RECT;
const LONG_PTR = windows.LONG_PTR;

pub extern "user32" fn GetForegroundWindow() callconv(WINAPI) ?HWND;

pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: LPRECT) callconv(WINAPI) BOOL;

// todo: on 32bit use SetWindowLong
pub extern "user32" fn SetWindowLongPtrA(
    hWnd: HWND,
    nIndex: c_int,
    dwNewLong: LONG_PTR,
) callconv(WINAPI) LONG_PTR;
