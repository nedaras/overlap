const std = @import("std");
const kernel32 = @import("windows/kernel32.zig");
const windows = std.os.windows;

pub usingnamespace windows;

pub const DLL_PROCESS_DETACH = 0;
pub const DLL_PROCESS_ATTACH = 1;
pub const DLL_THREAD_ATTACH = 2;
pub const DLL_THREAD_DETACH = 3;

pub const DisableThreadLibraryCallsError = error{Unexpected};

pub fn DisableThreadLibraryCalls(hLibModule: windows.HMODULE) DisableThreadLibraryCallsError!void {
    if (kernel32.DisableThreadLibraryCalls(hLibModule) == windows.FALSE) {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub const AllocConsoleError = error{
    AllreadyAllocated,
    Unexpected,
};

pub fn AllocConsole() AllocConsoleError!void {
    if (kernel32.AllocConsole() == windows.FALSE) {
        switch (windows.kernel32.GetLastError()) {
            .ACCESS_DENIED => return AllocConsoleError.AllreadyAllocated,
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

pub const GetModuleHandleError = error{Unexpected};

pub fn GetModuleHandle(lpModuleName: ?[:0]const u8) GetModuleHandleError!windows.HMODULE {
    const lpModuleName_ptr = if (lpModuleName) |slice| slice.ptr else null;

    return kernel32.GetModuleHandleA(lpModuleName_ptr) orelse {
        switch (windows.kernel32.GetLastError()) {
            else => |err| return windows.unexpectedError(err),
        }
    };
}
