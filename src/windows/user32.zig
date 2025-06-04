const std = @import("std");
const windows = std.os.windows;

const HWND = windows.HWND;
const WINAPI = windows.WINAPI;

pub extern "user32" fn GetForegroundWindow() callconv(WINAPI) ?HWND;
