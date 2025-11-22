const std = @import("std");
const windows = @import("windows.zig");
const detours = @import("detours.zig");
const Hooks = @import("Hooks.zig");
const Thread = std.Thread;

var count: u32 = 0;

pub export fn __overlap_hook_proc(code: c_int, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    return windows.user32.CallNextHookEx(null, code, wParam, lParam);
}

pub export fn DllMain(hinstDLL: windows.HINSTANCE, fdwReason: windows.DWORD, lpvReserved: windows.LPVOID) callconv(.winapi) windows.BOOL {
    _ = hinstDLL;
    _ = lpvReserved;

    switch (fdwReason) {
        windows.DLL_PROCESS_ATTACH => {
            std.log.info("count: {}", .{count});
            count += 1;
        },
        windows.DLL_PROCESS_DETACH => {},
        else => {},
    }

    return windows.TRUE;
}


fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";

    var buffer = [_]u8{'\x00'} ** 4096;
    const msg = std.fmt.bufPrintZ(&buffer, level_txt ++ prefix2 ++ format, args) catch blk: {
        buffer[buffer.len - 1] = '\x00';
        break :blk buffer[0..buffer.len - 1:0];
    };

    windows.OutputDebugString(msg);
}

pub const std_options: std.Options = .{
    .logFn = logFn,
};
