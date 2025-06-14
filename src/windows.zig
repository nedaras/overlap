const std = @import("std");
const kernel32 = @import("windows/kernel32.zig");
const psapi = @import("windows/psapi.zig");
const user32 = @import("windows/user32.zig");
const windows = std.os.windows;

pub usingnamespace windows;

pub const dxgi = @import("windows/dxgi.zig");
pub const d3d11 = @import("windows/d3d11.zig");
pub const d3dcommon = @import("windows/d3dcommon.zig");
pub const d3dcompiler = @import("windows/d3dcompiler.zig");

const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;

pub const REFIID = *const windows.GUID;

pub const DLL_PROCESS_DETACH = 0;
pub const DLL_PROCESS_ATTACH = 1;
pub const DLL_THREAD_ATTACH = 2;
pub const DLL_THREAD_DETACH = 3;

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
