const std = @import("std");
const windows = std.os.windows;

const WINAPI = windows.WINAPI;
const HMODULE = windows.HMODULE;
const BOOL = windows.BOOL;
const DWORD = windows.DWORD;

pub extern "kernel32" fn DisableThreadLibraryCalls(hLibModule: HMODULE) callconv(WINAPI) BOOL;

pub extern "kernel32" fn AllocConsole() callconv(WINAPI) BOOL;

pub extern "kernel32" fn FreeConsole() callconv(WINAPI) BOOL;

pub extern "kernel32" fn FreeLibraryAndExitThread(hLibModule: HMODULE, dwExitCode: DWORD) callconv(WINAPI) void;
