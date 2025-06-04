const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const WINAPI = windows.WINAPI;
const LPCSTR = windows.LPCSTR;
const HMODULE = windows.HMODULE;
const FARPROC = windows.FARPROC;

pub extern "kernel32" fn DisableThreadLibraryCalls(hLibModule: HMODULE) callconv(WINAPI) BOOL;

pub extern "kernel32" fn AllocConsole() callconv(WINAPI) BOOL;

pub extern "kernel32" fn FreeConsole() callconv(WINAPI) BOOL;

pub extern "kernel32" fn FreeLibraryAndExitThread(hLibModule: HMODULE, dwExitCode: DWORD) callconv(WINAPI) void;

pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?LPCSTR) callconv(WINAPI) ?HMODULE;

pub extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: LPCSTR) callconv(WINAPI) ?FARPROC;
