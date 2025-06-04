const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const WINAPI = windows.WINAPI;
const HANDLE = windows.HANDLE;
const HMODULE = windows.HMODULE;
const MODULEINFO = windows.MODULEINFO;

pub extern "psapi" fn GetModuleInformation(hProcess: HANDLE, hModule: HMODULE, lpmodinfo: *MODULEINFO, cb: DWORD) callconv(WINAPI) BOOL;
