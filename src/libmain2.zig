const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const detours = @import("detours.zig");
const root = @import("main.zig");
const d3d11 = windows.d3d11;
const dxgi = windows.dxgi;
const d3dcommon = windows.d3dcommon;

comptime {
    if (!builtin.is_test) switch (builtin.os.tag) {
        .windows => {
            @export(&__overlap_hook_proc, .{ .name = "__overlap_hook_proc" });
            @export(&DllMain, .{ .name = "DllMain" });
        },
        else => |os| @compileError("unsupported operating system: " ++ @tagName(os)),
    };
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

const LoadLibraryA = @TypeOf(hookedLoadLibraryA);
const LoadLibraryW = @TypeOf(hookedLoadLibraryW);
const Present = @TypeOf(hookedPresent);

var load_library_a: ?*LoadLibraryA = null;
var load_library_w: ?*LoadLibraryW = null;

var present: ?*Present = null;

pub fn __overlap_hook_proc(code: c_int, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(.winapi) windows.LRESULT {
    return windows.user32.CallNextHookEx(null, code, wParam, lParam);
}

pub fn DllMain(instance: windows.HINSTANCE, reason: windows.DWORD, reserved: windows.LPVOID) callconv(.winapi) windows.BOOL {
    _ = instance;
    _ = reserved;

    switch (reason) {
        windows.DLL_PROCESS_ATTACH => { //blk: {
            std.log.info("attaching: {d}", .{windows.GetCurrentProcessId()});
            //const kernel32 = windows.GetModuleHandle("kernel32") catch break :blk;

            //load_library_a = @ptrCast(@alignCast(windows.GetProcAddress(kernel32, "LoadLibraryA") catch unreachable));
            //load_library_w = @ptrCast(@alignCast(windows.GetProcAddress(kernel32, "LoadLibraryW") catch unreachable));

            //detours.attach(hookedLoadLibraryA, &load_library_a.?) catch {};
            //detours.attach(hookedLoadLibraryW, &load_library_w.?) catch {};
        },
        windows.DLL_PROCESS_DETACH => {
            std.log.info("detaching: {d}", .{windows.GetCurrentProcessId()});
            //if (load_library_a) |*proc| {
                //detours.detach(hookedLoadLibraryA, proc) catch {};
            //}

            //if (load_library_w) |*proc| {
                //detours.detach(hookedLoadLibraryW, proc) catch {};
            //}

            //if (present) |*proc| {
                //detours.detach(hookedPresent, proc) catch {};
            //}
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
        std.log.info("D3D11 matched", .{});
        hook_d3d11(library) catch {};
    }

    return library;
}

fn hookedLoadLibraryW(lpLibFileName: windows.LPCWSTR) callconv(.winapi) windows.HMODULE {
    const library = load_library_w.?(lpLibFileName);
    const lib_path = std.mem.span(lpLibFileName);

    if (std.mem.eql(u16, lib_path, std.unicode.wtf8ToWtf16LeStringLiteral("d3d11.dll"))) {
        std.log.info("D3D11 matched", .{});
        hook_d3d11(library) catch {};
    }

    return library;
}

fn hook_d3d11(library: windows.HMODULE) !void {
    const hwnd = try windows.CreateWindowEx(
        0,
        "STATIC",
        "Overlap DXGI Window",
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
    defer windows.DestroyWindow(hwnd);

    const D3D11CreateDeviceAndSwapChain = *const @TypeOf(d3d11.D3D11CreateDeviceAndSwapChain);
    const d3d11_create_device_and_swap_chain: D3D11CreateDeviceAndSwapChain = @ptrCast(try windows.GetProcAddress(
        library,
        "D3D11CreateDeviceAndSwapChain",
    ));

    var sd = std.mem.zeroes(dxgi.DXGI_SWAP_CHAIN_DESC);
    sd.BufferCount = 1;
    sd.BufferDesc.Format = dxgi.DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.OutputWindow = hwnd;
    sd.SampleDesc.Count = 1;
    sd.Windowed = windows.TRUE;
    sd.SwapEffect = dxgi.DXGI_SWAP_EFFECT_DISCARD;

    var swap_chain: *dxgi.IDXGISwapChain = undefined;

    var device: *d3d11.ID3D11Device = undefined;
    var device_context: *d3d11.ID3D11DeviceContext = undefined;

    const feature_levels = [_]d3dcommon.D3D_FEATURE_LEVEL{
        d3dcommon.D3D_FEATURE_LEVEL_11_0,
        d3dcommon.D3D_FEATURE_LEVEL_10_1,
        d3dcommon.D3D_FEATURE_LEVEL_10_0,
    };

    const hr = d3d11_create_device_and_swap_chain(
        null,
        d3dcommon.D3D_DRIVER_TYPE_HARDWARE,
        null,
        0,
        &feature_levels,
        feature_levels.len,
        d3d11.D3D11_SDK_VERSION,
        &sd,
        &swap_chain,
        &device,
        null,
        &device_context,
    );

    switch (d3d11.D3D11_ERROR_CODE(hr)) {
        .S_OK => {},
        else => |err| return d3d11.unexpectedError(err),
    }

    defer swap_chain.Release();
    defer device.Release();
    defer device_context.Release();

    std.log.info("DXGI initalized", .{});

    present = @constCast(@ptrCast(swap_chain.vtable[8]));

    try detours.attach(hookedPresent, &present.?);
}

fn hookedPresent(
    pSwapChain: *dxgi.IDXGISwapChain,
    SyncInterval: windows.UINT,
    Flags: windows.UINT,
) callconv(.winapi) windows.HRESULT {
    std.log.info("frame", .{});
    return present.?(pSwapChain, SyncInterval, Flags);
}
