const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const LPCSTR = windows.LPCSTR;
const HMODULE = windows.HMODULE;
const FARPROC = windows.FARPROC;

pub extern "kernel32" fn DisableThreadLibraryCalls(hLibModule: HMODULE) callconv(.winapi) BOOL;

pub extern "kernel32" fn AllocConsole() callconv(.winapi) BOOL;

pub extern "kernel32" fn FreeConsole() callconv(.winapi) BOOL;

pub extern "kernel32" fn FreeLibraryAndExitThread(hLibModule: HMODULE, dwExitCode: DWORD) callconv(.winapi) void;

pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?LPCSTR) callconv(.winapi) ?HMODULE;

pub extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: LPCSTR) callconv(.winapi) ?FARPROC;

pub extern "kernel32" fn SetConsoleTitleA(lpConsoleTitle: LPCSTR) callconv(.winapi) BOOL;
