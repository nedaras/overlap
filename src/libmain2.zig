const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");

extern fn DetourTransactionBegin() callconv(.c) windows.LONG;
extern fn DetourUpdateThread(hThread: windows.HANDLE) callconv(.c) windows.LONG;
extern fn DetourAttach(ppPointer: *?*anyopaque, pDetour: ?*const anyopaque) callconv(.c) windows.LONG;
extern fn DetourDetach(ppPointer: *?*anyopaque, pDetour: ?*const anyopaque) callconv(.c) windows.LONG;
extern fn DetourTransactionCommit() callconv(.c) windows.LONG;

comptime {
    if (!builtin.is_test) switch (builtin.os.tag) {
        .windows => {
            @export(&__overlap_hook_proc, .{ .name = "__overlap_hook_proc" });
            @export(&DllMain, .{ .name = "DllMain" });
        },
        else => |os| @compileError("unsupported operating system: " ++ @tagName(os)),
    };
}

const LoadLibraryA = @TypeOf(hookedLoadLibraryA);
const LoadLibraryW = @TypeOf(hookedLoadLibraryW);

var load_library_a: ?*LoadLibraryA = null;
var load_library_w: ?*LoadLibraryW = null;

pub fn __overlap_hook_proc(code: c_int, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    return windows.user32.CallNextHookEx(null, code, wParam, lParam);
}

pub fn DllMain(instance: windows.HINSTANCE, reason: windows.DWORD, reserved: windows.LPVOID) callconv(.winapi) windows.BOOL {
    _ = reserved;

    switch (reason) {
        windows.DLL_PROCESS_ATTACH => blk: {
            const kernel32 = windows.GetModuleHandle("kernel32") catch break :blk;

            load_library_a = @ptrCast(@alignCast(windows.GetProcAddress(kernel32, "LoadLibraryA") catch unreachable));
            load_library_w = @ptrCast(@alignCast(windows.GetProcAddress(kernel32, "LoadLibraryW") catch unreachable));

            _ = DetourTransactionBegin();

            _ = DetourAttach(&load_library_a, &hookedLoadLibraryA);
            _ = DetourAttach(&load_library_a, &hookedLoadLibraryA);

            const ret = DetourTransactionCommit();
            std.debug.print("done with: {d}\n", .{ret});

            windows.DisableThreadLibraryCalls(@ptrCast(instance)) catch {};
        },
        windows.DLL_PROCESS_DETACH => {
            _ = DetourTransactionBegin();

            _ = DetourDetach(&load_library_a, &hookedLoadLibraryA);
            _ = DetourDetach(&load_library_a, &hookedLoadLibraryA);

            _ = DetourTransactionCommit();
        },
        else => {},
    }

    return windows.TRUE;
}

// So idea is just to wait till process tries to load d3d11.dll, and only then we hook it

fn hookedLoadLibraryA(lpLibFileName: windows.LPCSTR) callconv(.winapi) windows.HMODULE {
    const library = load_library_a.?(lpLibFileName);

    windows.kernel32.OutputDebugStringA(lpLibFileName);

    return library;
}

fn hookedLoadLibraryW(lpLibFileName: windows.LPCWSTR) callconv(.winapi) windows.HMODULE {
    const library = load_library_w.?(lpLibFileName);

    windows.kernel32.OutputDebugStringW(lpLibFileName);

    return library;
}
