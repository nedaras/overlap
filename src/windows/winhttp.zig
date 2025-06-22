const std = @import("std");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const WINAPI = windows.WINAPI;
const DWORD = windows.DWORD;
const LPVOID = windows.LPVOID;
const LPCWSTR = windows.LPCWSTR;
const LPCVOID = windows.LPCVOID;
const WCHAR = windows.WCHAR;
const LPDWORD = *windows.DWORD;

pub const HINTERNET = *opaque {};
pub const INTERNET_PORT = windows.USHORT;

pub extern "winhttp" fn WinHttpOpen(
    pszAgentW: ?LPCWSTR,
    dwAccessType: DWORD,
    pszProxyW: ?LPCWSTR,
    pszProxyBypassW: ?LPCWSTR,
    dwFlags: DWORD,
) callconv(WINAPI) ?HINTERNET;

pub extern "winhttp" fn WinHttpCloseHandle(hInternet: HINTERNET) callconv(WINAPI) BOOL;

pub extern "winhttp" fn WinHttpConnect(
    hSession: HINTERNET,
    pswzServerName: LPCWSTR,
    nServerPort: INTERNET_PORT,
    dwReserved: DWORD,
) callconv(WINAPI) ?HINTERNET;

pub extern "winhttp" fn WinHttpOpenRequest(
    hConnect: HINTERNET,
    pwszVerb: LPCWSTR,
    pwszObjectName: LPCWSTR,
    pwszVersion: ?LPCWSTR,
    pwszReferrer: ?LPCWSTR,
    ppwszAcceptTypes: [*:null]const ?LPCWSTR,
    dwFlags: DWORD,
) callconv(WINAPI) ?HINTERNET;

pub extern "winhttp" fn WinHttpSendRequest(
    hRequest: HINTERNET,
    lpszHeaders: ?[*]const WCHAR,
    dwHeadersLength: DWORD,
    lpOptional: ?LPCVOID,
    dwOptionalLength: DWORD,
    dwTotalLength: DWORD,
    dwContext: ?*DWORD,
) callconv(WINAPI) BOOL;

pub extern "winhttp" fn WinHttpReceiveResponse(hRequest: HINTERNET, lpReserved: ?LPCVOID) callconv(WINAPI) BOOL;

pub extern "winhttp" fn WinHttpQueryHeaders(
    hRequest: HINTERNET,
    dwInfoLevel: DWORD,
    pwszName: ?LPCWSTR,
    lpBuffer: LPCVOID,
    lpdwBufferLength: LPDWORD,
    lpdwIndex: ?LPDWORD,
) callconv(WINAPI) BOOL;

pub extern "winhttp" fn WinHttpReadData(
    hRequest: HINTERNET,
    lpBuffer: LPVOID,
    dwNumberOfBytesToRead: DWORD,
    lpdwNumberOfBytesRead: LPDWORD,
) callconv(WINAPI) BOOL;
