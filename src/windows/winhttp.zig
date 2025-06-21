const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const WINAPI = windows.WINAPI;
const DWORD = windows.DWORD;
const LPCWSTR = windows.LPCWSTR;

pub const HINTERNET = *opaque {};

pub extern "winhttp" fn WinHttpOpen(
    pszAgentW: ?LPCWSTR,
    dwAccessType: DWORD,
    pszProxyW: ?LPCWSTR,
    pszProxyBypassW: ?LPCWSTR,
    dwFlags: DWORD,
) callconv(WINAPI) ?HINTERNET;

pub extern "winhttp" fn WinHttpCloseHandle(hInternet: HINTERNET) callconv(WINAPI) BOOL;
