const std = @import("std");
const kernel32 = @import("windows/kernel32.zig");
const psapi = @import("windows/psapi.zig");
const user32 = @import("windows/user32.zig");
const winhttp = @import("windows/winhttp.zig");
const windows = std.os.windows;
const unicode = std.unicode;
const assert = std.debug.assert;

pub usingnamespace windows;

pub const dxgi = @import("windows/dxgi.zig");
pub const d3d11 = @import("windows/d3d11.zig");
pub const d3dcommon = @import("windows/d3dcommon.zig");
pub const d3dcompiler = @import("windows/d3dcompiler.zig");

const TRUE = windows.TRUE;
const FALSE = windows.FALSE;
const ULONG = windows.ULONG;
const DWORD = windows.DWORD;
const WINAPI = windows.WINAPI;
const LPCWSTR = windows.LPCWSTR;
const HRESULT = windows.HRESULT;
const LPCVOID = windows.LPCVOID;
const LPDWORD = *windows.DWORD;
const Win32Error = windows.Win32Error;

pub const REFIID = *const windows.GUID;
pub const HINTERNET = winhttp.HINTERNET;
pub const INTERNET_PORT = winhttp.INTERNET_PORT;

pub const DLL_PROCESS_DETACH = 0;
pub const DLL_PROCESS_ATTACH = 1;
pub const DLL_THREAD_ATTACH = 2;
pub const DLL_THREAD_DETACH = 3;

pub const WINHTTP_ACCESS_TYPE_DEFAULT_PROXY = 0;
pub const WINHTTP_ACCESS_TYPE_NO_PROXY = 1;

pub const WINHTTP_NO_PROXY_NAME = null;
pub const WINHTTP_NO_PROXY_BYPASS = null;
pub const WINHTTP_NO_REFERER = null;
pub const WINHTTP_NO_REQUEST_DATA = null;
pub const WINHTTP_NO_ADDITIONAL_HEADERS = null;
pub const WINHTTP_NO_HEADER_INDEX = null;

pub const WINHTTP_HEADER_NAME_BY_INDEX = null;

pub const WINHTTP_FLAG_SECURE = 0x00800000;

pub const WINHTTP_DEFAULT_ACCEPT_TYPES = &[_:null]?LPCWSTR{
    unicode.wtf8ToWtf16LeStringLiteral("*/*"),
};

pub const WINHTTP_QUERY_STATUS_CODE = 19;
pub const WINHTTP_QUERY_FLAG_NUMBER = 0x20000000;

pub const IUnknown = extern struct {
    vtable: *const IUnknownVTable,

    pub const QueryInterfaceError = error{
        InterfaceNotFound,
        Unexpected,
    };

    pub fn QueryInterface(self: *IUnknown, riid: REFIID, ppvObject: **anyopaque) QueryInterfaceError!void {
        const hr = self.vtable.QueryInterface(self, riid, ppvObject);
        return switch (hr) {
            windows.S_OK => void,
            windows.E_NOINTERFACE => error.InterfaceNotFound,
            windows.E_POINTER => unreachable,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub inline fn AddRef(self: *IUnknown) ULONG {
        return self.vtable.AddRef(self);
    }

    pub inline fn Release(self: *IUnknown) void {
        _ = self.vtable.Release(self);
    }
};

const IUnknownVTable = extern struct {
    QueryInterface: *const fn (self: *IUnknown, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT,
    AddRef: *const fn (self: *IUnknown) callconv(WINAPI) ULONG,
    Release: *const fn (self: *IUnknown) callconv(WINAPI) ULONG,
};

pub const DisableThreadLibraryCallsError = error{Unexpected};

pub fn DisableThreadLibraryCalls(hLibModule: windows.HMODULE) DisableThreadLibraryCallsError!void {
    if (kernel32.DisableThreadLibraryCalls(hLibModule) == windows.FALSE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub const AllocConsoleError = error{
    AccessDenied,
    Unexpected,
};

pub fn AllocConsole() AllocConsoleError!void {
    if (kernel32.AllocConsole() == windows.FALSE) {
        switch (windows.kernel32.GetLastError()) {
            .ACCESS_DENIED => return error.AccessDenied,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub const FreeConsoleError = error{Unexpected};

pub fn FreeConsole() FreeConsoleError!void {
    if (kernel32.FreeConsole() == windows.FALSE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub inline fn FreeLibraryAndExitThread(hLibModule: windows.HMODULE, dwExitCode: u32) void {
    kernel32.FreeLibraryAndExitThread(hLibModule, dwExitCode);
}

pub const GetModuleHandleError = error{
    ModuleNotFound,
    Unexpected,
};

pub fn GetModuleHandle(lpModuleName: ?[:0]const u8) GetModuleHandleError!windows.HMODULE {
    const lpModuleName_ptr = if (lpModuleName) |slice| slice.ptr else null;

    return kernel32.GetModuleHandleA(lpModuleName_ptr) orelse {
        switch (windows.kernel32.GetLastError()) {
            .MOD_NOT_FOUND => return error.ModuleNotFound,
            else => |err| return windows.unexpectedError(err),
        }
    };
}

pub const GetModuleInformationError = error{Unexpected};

pub fn GetModuleInformation(hProcess: windows.HANDLE, hModule: windows.HMODULE) GetModuleInformationError!windows.MODULEINFO {
    var module_info: windows.MODULEINFO = undefined;
    if (psapi.GetModuleInformation(hProcess, hModule, &module_info, @sizeOf(windows.MODULEINFO)) == windows.FALSE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
    return module_info;
}

pub const GetProcAddressError = error{ ProcedureNotFound, Unexpected };

pub fn GetProcAddress(hModule: windows.HMODULE, lpProcName: [:0]const u8) GetProcAddressError!windows.FARPROC {
    return kernel32.GetProcAddress(hModule, lpProcName) orelse {
        switch (windows.kernel32.GetLastError()) {
            .PROC_NOT_FOUND => return error.ProcedureNotFound,
            else => |err| return windows.unexpectedError(err),
        }
    };
}

pub inline fn GetForegroundWindow() ?windows.HWND {
    return user32.GetForegroundWindow();
}

pub const GetWindowRectError = error{Unexpected};

pub fn GetWindowRect(hWnd: windows.HWND) GetWindowRectError!windows.RECT {
    var rect: windows.RECT = undefined;
    if (user32.GetWindowRect(hWnd, &rect) == windows.FALSE) {
        return switch (windows.kernel32.GetLastError()) {
            else => |err| windows.unexpectedError(err),
        };
    }

    return rect;
}

pub const WinHttpOpenError = error{Unexpected};

pub fn WinHttpOpen(
    pszAgentW: ?[:0]const u16,
    dwAccessType: DWORD,
    pszProxyW: ?[:0]const u16,
    pszProxyBypassW: ?[:0]const u16,
    dwFlags: DWORD,
) WinHttpOpenError!HINTERNET {
    const pszAgentW_ptr = if (pszAgentW) |slice| slice.ptr else null;
    const pszProxyW_ptr = if (pszProxyW) |slice| slice.ptr else null;
    const pszProxyBypassW_ptr = if (pszProxyBypassW) |slice| slice.ptr else null;

    if (winhttp.WinHttpOpen(pszAgentW_ptr, dwAccessType, pszProxyW_ptr, pszProxyBypassW_ptr, dwFlags)) |session| {
        return session;
    }

    return switch (windows.kernel32.GetLastError()) {
        else => |err| windows.unexpectedError(err),
    };
}

pub fn WinHttpCloseHandle(hInternet: HINTERNET) void {
    assert(winhttp.WinHttpCloseHandle(hInternet) == TRUE);
}

pub const WinHttpConnectError = error{
    NetworkUnreachable,
    Unexpected,
};

pub fn WinHttpConnect(
    hSession: HINTERNET,
    pswzServerName: [:0]const u16,
    nServerPort: INTERNET_PORT,
    dwReserved: DWORD,
) WinHttpConnectError!HINTERNET {
    if (winhttp.WinHttpConnect(hSession, pswzServerName.ptr, nServerPort, dwReserved)) |connection| {
        return connection;
    }

    return switch (windows.kernel32.GetLastError()) {
        @as(Win32Error, @enumFromInt(12007)) => error.NetworkUnreachable,
        else => |err| windows.unexpectedError(err),
    };
}

pub const WinHttpOpenRequestError = error{Unexpected};

pub fn WinHttpOpenRequest(
    hConnect: HINTERNET,
    pwszVerb: [:0]const u16,
    pwszObjectName: [:0]const u16,
    pwszVersion: ?[:0]const u16,
    pwszReferrer: ?[:0]const u16,
    ppwszAcceptTypes: [:null]const ?LPCWSTR,
    dwFlags: DWORD,
) WinHttpOpenRequestError!HINTERNET {
    const pwszVersion_ptr = if (pwszVersion) |slice| slice.ptr else null;
    const pwszReferrer_ptr = if (pwszReferrer) |slice| slice.ptr else null;

    if (winhttp.WinHttpOpenRequest(hConnect, pwszVerb.ptr, pwszObjectName.ptr, pwszVersion_ptr, pwszReferrer_ptr, ppwszAcceptTypes.ptr, dwFlags)) |request| {
        return request;
    }

    return switch (windows.kernel32.GetLastError()) {
        else => |err| windows.unexpectedError(err),
    };
}

pub const WinHttpSendRequestError = error{Unexpected};

pub fn WinHttpSendRequest(
    hRequest: HINTERNET,
    Headers: ?[]const u16,
    Optional: ?[]const u16,
    dwTotalLength: DWORD,
    dwContext: ?*DWORD,
) WinHttpSendRequestError!void {
    const lpszHeaders = if (Headers) |slice| slice.ptr else null;
    const dwHeadersLength: DWORD = if (Headers) |slice| @intCast(slice.len) else 0;

    const lpOptional = if (Optional) |slice| slice.ptr else null;
    const dwOptionalLength: DWORD = if (Optional) |slice| @intCast(slice.len) else 0;

    if (winhttp.WinHttpSendRequest(hRequest, lpszHeaders, dwHeadersLength, lpOptional, dwOptionalLength, dwTotalLength, dwContext) == FALSE) {
        return switch (windows.kernel32.GetLastError()) {
            else => |err| windows.unexpectedError(err),
        };
    }
}

pub const WinHttpReceiveResponseError = error{Unexpected};

pub fn WinHttpReceiveResponse(hRequest: HINTERNET) WinHttpOpenRequestError!void {
    if (winhttp.WinHttpReceiveResponse(hRequest, null) == FALSE) {
        return switch (windows.kernel32.GetLastError()) {
            else => |err| windows.unexpectedError(err),
        };
    }
}

pub const WinHttpQueryHeadersError = error{Unexpected};

pub fn WinHttpQueryHeaders(
    hRequest: HINTERNET,
    dwInfoLevel: DWORD,
    Name: ?[:0]const u16,
    lpBuffer: LPCVOID,
    lpdwBufferLength: LPDWORD,
    lpdwIndex: ?LPDWORD,
) WinHttpQueryHeadersError!void {
    const pwszName = if (Name) |slice| slice.ptr else null;

    if (winhttp.WinHttpQueryHeaders(hRequest, dwInfoLevel, pwszName, lpBuffer, lpdwBufferLength, lpdwIndex) == FALSE) {
        return switch (windows.kernel32.GetLastError()) {
            else => |err| windows.unexpectedError(err),
        };
    }
}
