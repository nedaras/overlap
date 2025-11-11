const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const detours = @import("detours.zig");
const root = @import("main.zig");

comptime {
    if (!builtin.is_test) switch (builtin.os.tag) {
        .windows => {
            @export(&__overlap_hook_proc, .{ .name = "__overlap_hook_proc" });
            @export(&DllMain, .{ .name = "DllMain" });
        },
        else => |os| @compileError("unsupported operating system: " ++ @tagName(os)),
    };
}

pub const options: std.Options = if (@hasDecl(root, "std_options")) root.std_options else .{};

const LoadLibraryA = @TypeOf(hookedLoadLibraryA);
const LoadLibraryW = @TypeOf(hookedLoadLibraryW);

var load_library_a: ?*LoadLibraryA = null;
var load_library_w: ?*LoadLibraryW = null;

pub fn __overlap_hook_proc(code: c_int, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    return windows.user32.CallNextHookEx(null, code, wParam, lParam);
}

pub fn DllMain(instance: windows.HINSTANCE, reason: windows.DWORD, reserved: windows.LPVOID) callconv(.winapi) windows.BOOL {
    _ = instance;
    _ = reserved;

    switch (reason) {
        windows.DLL_PROCESS_ATTACH => blk: {
            const kernel32 = windows.GetModuleHandle("kernel32") catch break :blk;

            load_library_a = @ptrCast(@alignCast(windows.GetProcAddress(kernel32, "LoadLibraryA") catch unreachable));
            load_library_w = @ptrCast(@alignCast(windows.GetProcAddress(kernel32, "LoadLibraryW") catch unreachable));

            detours.attach(hookedLoadLibraryA, &load_library_a.?) catch {};
            detours.attach(hookedLoadLibraryW, &load_library_w.?) catch {};
        },
        windows.DLL_PROCESS_DETACH => {
            windows.kernel32.OutputDebugStringA("Overlap: Cleanup now!");
            if (load_library_a) |*proc| {
                detours.detach(hookedLoadLibraryA, proc) catch {};
            }

            if (load_library_w) |*proc| {
                detours.detach(hookedLoadLibraryW, proc) catch {};
            }
        },
        else => {},
    }

    return windows.TRUE;
}

// So idea is just to wait till process tries to load d3d11.dll, and only then we hook it

fn hookedLoadLibraryA(lpLibFileName: windows.LPCSTR) callconv(.winapi) windows.HMODULE {
    const library = load_library_a.?(lpLibFileName);

    const lib_path = std.mem.span(lpLibFileName);
    if (std.mem.eql(u8, lib_path, "d3d11.dll")) {
        windows.kernel32.OutputDebugStringA("Overlap: D3D11 matched");
    }

    return library;
}

fn hookedLoadLibraryW(lpLibFileName: windows.LPCWSTR) callconv(.winapi) windows.HMODULE {
    const library = load_library_w.?(lpLibFileName);

    const lib_path = std.mem.span(lpLibFileName);
    if (std.mem.eql(u16, lib_path, std.unicode.wtf8ToWtf16LeStringLiteral("d3d11.dll"))) {
        windows.kernel32.OutputDebugStringA("Overlap: D3D11 matched");
    }

    return library;
}
