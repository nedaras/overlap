const windows = @import("windows.zig");
const Win32Error = windows.Win32Error;

extern fn DetourTransactionBegin() callconv(.c) windows.LONG;
extern fn DetourUpdateThread(hThread: windows.HANDLE) callconv(.c) windows.LONG;
extern fn DetourAttach(ppPointer: *windows.LPVOID, pDetour: windows.LPCVOID) callconv(.c) windows.LONG;
extern fn DetourDetach(ppPointer: *windows.LPVOID, pDetour: windows.LPCVOID) callconv(.c) windows.LONG;
extern fn DetourTransactionCommit() callconv(.c) windows.LONG;
extern fn DetourTransactionAbort() callconv(.c) windows.LONG;

pub const AttachError = error{
    Modified,
    PendingTransaction,
    FunctionTooSmall,
    OutOfMemory,
    Unexpected,
};

pub fn attach(comptime Detour: anytype, ptr: **@TypeOf(Detour)) AttachError!void {
    switch (@as(Win32Error, @enumFromInt(DetourTransactionBegin()))) {
        .SUCCESS => {},
        @as(Win32Error, @enumFromInt(4317)) => return error.PendingTransaction, // ERROR_INVALID_OPERATION
        else => |e| return windows.unexpectedError(e),
    }

    {
        errdefer _ = DetourTransactionAbort();
        switch (@as(Win32Error, @enumFromInt(DetourAttach(ptr, &Detour)))) {
            .SUCCESS => {},
            .INVALID_BLOCK => return error.FunctionTooSmall,
            .INVALID_HANDLE => unreachable,
            @as(Win32Error, @enumFromInt(4317)) => unreachable, // ERROR_INVALID_OPERATION
            .NOT_ENOUGH_MEMORY => return error.OutOfMemory,
            else => |e| return windows.unexpectedError(e),
        }
    }

    switch (@as(Win32Error, @enumFromInt(DetourTransactionCommit()))) {
        .SUCCESS => {},
        .INVALID_DATA => return error.Modified,
        @as(Win32Error, @enumFromInt(4317)) => unreachable, // ERROR_INVALID_OPERATION
        else => |e| return windows.unexpectedError(e),
    }
}


pub const DetachError = error{
    Modified,
    PendingTransaction,
    FunctionTooSmall, // it means thaat function is not hooked
    OutOfMemory,
    Unexpected,
};

pub fn detach(comptime Detour: anytype, ptr: **@TypeOf(Detour)) DetachError!void {
    switch (@as(Win32Error, @enumFromInt(DetourTransactionBegin()))) {
        .SUCCESS => {},
        @as(Win32Error, @enumFromInt(4317)) => return error.PendingTransaction, // ERROR_INVALID_OPERATION
        else => |e| return windows.unexpectedError(e),
    }

    {
        errdefer _ = DetourTransactionAbort();
        switch (@as(Win32Error, @enumFromInt(DetourDetach(ptr, &Detour)))) {
            .SUCCESS => {},
            .INVALID_BLOCK => return error.FunctionTooSmall,
            .INVALID_HANDLE => unreachable,
            @as(Win32Error, @enumFromInt(4317)) => unreachable, // ERROR_INVALID_OPERATION
            .NOT_ENOUGH_MEMORY => return error.OutOfMemory,
            else => |e| return windows.unexpectedError(e),
        }
    }

    switch (@as(Win32Error, @enumFromInt(DetourTransactionCommit()))) {
        .SUCCESS => {},
        .INVALID_DATA => return error.Modified,
        @as(Win32Error, @enumFromInt(4317)) => unreachable, // ERROR_INVALID_OPERATION
        else => |e| return windows.unexpectedError(e),
    }
}
