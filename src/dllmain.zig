const std = @import("std");
const windows = @import("windows.zig");
const root = @import("main.zig");
const Thread = std.Thread;

pub export fn DllMain(instance: windows.HINSTANCE, reason: windows.DWORD, reserved: windows.LPVOID) callconv(windows.WINAPI) windows.BOOL {
    if (reason == windows.DLL_PROCESS_ATTACH) windows.AllocConsole() catch |err| switch (err) {
        error.AccessDenied => {},
        else => return windows.FALSE,
    };

    return tracedDllMain(instance, reason, reserved) catch |err| blk: {
        std.debug.print("error: {s}\n", .{@errorName(err)});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }

        break :blk windows.FALSE;
    };
}

inline fn tracedDllMain(instance: windows.HINSTANCE, reason: windows.DWORD, _: windows.LPVOID) (windows.DisableThreadLibraryCallsError || Thread.SpawnError)!windows.BOOL {
    if (reason == windows.DLL_PROCESS_ATTACH) {
        try windows.DisableThreadLibraryCalls(@ptrCast(instance));

        const thread = try Thread.spawn(.{}, entry, .{instance});
        thread.detach();
        
        return windows.TRUE;
    }

    return windows.FALSE;
}

fn entry(instance: windows.HINSTANCE) void {
    root.main() catch |err| {
        std.debug.print("error: {s}\n", .{@errorName(err)});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
    };

    const stdin = std.io.getStdIn();
    _ = stdin.reader().readByte() catch {};

    windows.FreeConsole() catch {};
    windows.FreeLibraryAndExitThread(@ptrCast(instance), 0);
}
