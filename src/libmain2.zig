const std = @import("std");
const windows = @import("windows.zig");
const detours = @import("detours.zig");
const Hooks = @import("Hooks.zig");

const mem = std.mem;

var hooks: Hooks = .init;

var load_library_a: ?*@TypeOf(LoadLibraryA) = null;
var load_library_w: ?*@TypeOf(LoadLibraryW) = null;

fn attach() void {
}

pub export fn __overlap_hook_proc(code: c_int, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    return windows.user32.CallNextHookEx(null, code, wParam, lParam);
}

pub export fn DllMain(hinstDLL: windows.HINSTANCE, fdwReason: windows.DWORD, lpvReserved: windows.LPVOID) callconv(.winapi) windows.BOOL {
    _ = hinstDLL;
    _ = lpvReserved;

    switch (fdwReason) {
        windows.DLL_PROCESS_ATTACH => {
            //const kernel32 = windows.GetModuleHandle("kernel32.dll") orelse {
                //std.log.err("module 'kernel32.dll' is not loaded.", .{});
                //return windows.FALSE;
            //};

            //load_library_a = @ptrCast(windows.GetProcAddress(kernel32, "LoadLibraryA") catch return windows.FALSE);
            //load_library_w = @ptrCast(windows.GetProcAddress(kernel32, "LoadLibraryW") catch return windows.FALSE);

            //detours.attach(LoadLibraryA, &load_library_a.?) catch |err| {
                //std.log.err("failed to hook 'LoadLibraryA': {}`", .{err});
                //load_library_a = null;
                //return windows.FALSE;
            //};
            //std.log.info("hooked 'LoadLibraryA'", .{});

            //detours.attach(LoadLibraryW, &load_library_w.?) catch |err| {
                //std.log.err("failed to hook 'LoadLibraryW': {}`", .{err});
                //load_library_w = null;
                //return windows.FALSE;
            //};
            //std.log.info("hooked 'LoadLibraryA'", .{});

            if (windows.GetModuleHandle("d3d11.dll")) |d3d11| {
                _ = d3d11;
                std.log.info("d3d11 is already loaded!", .{});

                //hooks.attach(.{ .d3d11 = d3d11 }) catch |err| {
                    //std.log.err("could not hook d3d11: {}", .{err});
                    //return windows.FALSE;
                //};

                //std.log.info("hooked d3d11", .{});
            }
        },
        windows.DLL_PROCESS_DETACH => {
            // !!! if d3d11 is unloaded this will probably fail rly badly
            // hook FreeLibrary i guess idk
            hooks.deinit();

            if (load_library_a) |*func| {
                detours.detach(LoadLibraryA, func) catch {};
                load_library_a = null;
            }

            if (load_library_w) |*func| {
                detours.detach(LoadLibraryW, func) catch {};
                load_library_w = null;
            }
        },
        else => {},
    }

    return windows.TRUE;
}

fn LoadLibraryA(lpLibFileName: windows.LPCSTR) callconv(.winapi) ?windows.HMODULE {
    const library = load_library_a.?(lpLibFileName) orelse return null;

    if (mem.eql(u8, mem.span(lpLibFileName), "d3d11.dll")) blk: {
        hooks.attach(.{ .d3d11 = library }) catch |err| {
            std.log.err("could not hook d3d11: {}", .{err});
            break :blk;
        };

        std.log.info("hooked d3d11", .{});
    }

    return library;
}

fn LoadLibraryW(lpLibFileName: windows.LPCWSTR) callconv(.winapi) ?windows.HMODULE {
    const library = load_library_w.?(lpLibFileName) orelse return null;

    if (mem.eql(u16, mem.span(lpLibFileName), std.unicode.wtf8ToWtf16LeStringLiteral("d3d11.dll"))) blk: {
        hooks.attach(.{ .d3d11 = library }) catch |err| {
            std.log.err("could not hook d3d11: {}", .{err});
            break :blk;
        };

        std.log.info("hooked d3d11", .{});
    }

    return library;
}

pub fn logFn(
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
