const std = @import("std");
const windows = std.os.windows;

const HWND = windows.HWND;
const BOOL = windows.BOOL;
const WINAPI = windows.WINAPI;
const LPRECT = *windows.RECT;

pub extern "user32" fn GetForegroundWindow() callconv(WINAPI) ?HWND;

pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: LPRECT) callconv(WINAPI) BOOL;
