const std = @import("std");
const windows = @import("windows.zig");
const graphics = @import("graphics.zig");
const d3d11 = @import("hooks/d3d11.zig");
const Gui = @import("Gui2.zig");
const detours = @import("detours.zig");

const mem = std.mem;
const unicode = std.unicode;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

const Hooks = @This();

mutex: Mutex = .{},
established_hooks: EstablishedHooks = .{},

load_library_a: *@TypeOf(LoadLibraryA),
load_library_w: *@TypeOf(LoadLibraryW),

var self: ?Hooks = null;

const EstablishedHooks = packed struct {
    d3d11: bool = false,
};

// return smth like error.Failed
pub fn init() !void {
    assert(self == null);

    const kernel32 = windows.GetModuleHandle("kernel32") orelse return error.ModuleNotFound;

    var load_library_a: *@TypeOf(LoadLibraryA) = @ptrCast(try windows.GetProcAddress(kernel32, "LoadLibraryA"));
    var load_library_w: *@TypeOf(LoadLibraryW) = @ptrCast(try windows.GetProcAddress(kernel32, "LoadLibraryW"));

    try detours.attach(LoadLibraryA, &load_library_a);
    errdefer detours.detach(LoadLibraryA, &load_library_a) catch {};

    try detours.attach(LoadLibraryW, &load_library_w);
    errdefer detours.detach(LoadLibraryW, &load_library_w) catch {};

    self = .{
        .load_library_a = load_library_a,
        .load_library_w = load_library_w,
    };
}

pub fn deinit() void {
    const hooks = &self.?;

    detours.detach(LoadLibraryA, &hooks.load_library_a) catch {};
    detours.detach(LoadLibraryW, &hooks.load_library_w) catch {};

    if (hooks.established_hooks.d3d11) {
        d3d11.detach();
    }
}

fn LoadLibraryA(lpLibFileName: windows.LPCSTR) ?windows.HMODULE {
    const hooks = &self.?;

    const lib = hooks.load_library_a(lpLibFileName) orelse return null;
    const lib_name = mem.span(lpLibFileName);

    if (mem.eql(u8, lib_name, "d3d11.dll")) {
        hooks.mutex.lock();
        defer hooks.mutex.unlock();

        const window = makeDummyWindow() catch unreachable;
        defer windows.DestroyWindow(window);

        d3d11.attach(lib, window, &hooks.mutex) catch unreachable;
    }

    return lib;
}

fn LoadLibraryW(lpLibFileName: windows.LPCWSTR) ?windows.HMODULE {
    const hooks = &self.?;

    const lib = hooks.load_library_w(lpLibFileName) orelse return null;
    const lib_name = mem.span(lpLibFileName);

    if (mem.eql(u16, lib_name, unicode.wtf8ToWtf16LeStringLiteral("d3d11.dll"))) {
        hooks.mutex.lock();
        defer hooks.mutex.unlock();

        const window = makeDummyWindow() catch unreachable;
        defer windows.DestroyWindow(window);

        d3d11.attach(lib, window, &hooks.mutex) catch unreachable;
    }

    return lib;
}

/// Returned handle should be destroyed with `windows.DestroyWindow` when no longer used.
fn makeDummyWindow() windows.CreateWindowExError!windows.HWND {
    return windows.CreateWindowEx(
        0,
        "STATIC",
        "Overlap Dummy Window",
        windows.WS_OVERLAPPEDWINDOW,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        640,
        480,
        null,
        null,
        null,
        null,
    );
}
