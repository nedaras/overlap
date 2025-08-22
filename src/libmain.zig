const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const root = @import("main.zig");
const Thread = std.Thread;

comptime {
    if (!builtin.is_test) switch (builtin.os.tag) {
        .windows => @export(&DllMain, .{ .name = "DllMain" }),
        else => |os| @compileError("unsupported operating system: " ++ @tagName(os)),
    };
}

fn entry(instance: windows.HINSTANCE) void {
    root.main() catch |err| {
        std.debug.print("error: {s}\n", .{@errorName(err)});
        if (@errorReturnTrace()) |trace| {
            std.debug.dumpStackTrace(trace.*);
        }
    };

    if (builtin.mode == .Debug) {
        var byte: [1]u8 = undefined;
        const stdin: std.fs.File = .stdin();

        _ = stdin.read(&byte) catch {};
        windows.FreeConsole() catch {};
    }

    windows.FreeLibraryAndExitThread(@ptrCast(instance), 0);
}

pub fn DllMain(instance: windows.HINSTANCE, reason: windows.DWORD, reserved: windows.LPVOID) callconv(.winapi) windows.BOOL {
    if (builtin.mode == .Debug) {
        if (reason == windows.DLL_PROCESS_ATTACH) {
            windows.AllocConsole() catch |err| switch (err) {
                error.AccessDenied => {},
                else => return windows.FALSE,
            };

            windows.SetConsoleTitle("overlap") catch return windows.FALSE;
        }
    }

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

test {
    _ = @import("actions.zig");
}
