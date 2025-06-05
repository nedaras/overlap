const std = @import("std");
const windows = std.os.windows;

pub const d3d11 = @import("d3d11.zig");
pub const DXGI_ERROR = @import("dxgi_error.zig").DXGI_ERROR;

const INT = windows.INT;
const S_OK = windows.S_OK;
const HWND = windows.HWND;
const BOOL = windows.BOOL;
const UINT = windows.UINT;
const ULONG = windows.ULONG;
const HRESULT = windows.HRESULT;
const REFCIID = *const windows.GUID;
const WINAPI = windows.WINAPI;

pub const IDXGISwapChain = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *IDXGISwapChain) void {
        const FnType = fn (*anyopaque) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }

    pub fn GetDevice(self: *IDXGISwapChain, riid: REFCIID, ppDevice: **anyopaque) !void {
        const FnType = fn (*anyopaque, REFCIID, **anyopaque) callconv(WINAPI) HRESULT;
        const get_device: *const FnType = @ptrCast(self.vtable[7]);

        const hr = get_device(self, riid, ppDevice);
        return switch (DXGI_ERROR_CODE(hr)) {
            .SUCCESS => {},
            else => |err| unexpectedError(err),
        };
    }
};

pub const IDXGIAdapter = *opaque{};

pub const DXGI_FORMAT = INT;
pub const DXGI_FORMAT_R8G8B8A8_UNORM = 28;

pub const DXGI_SWAP_EFFECT = INT;
pub const DXGI_SWAP_EFFECT_DISCARD = 0;

pub const DXGI_USAGE = INT;
pub const DXGI_USAGE_RENDER_TARGET_OUTPUT = 32;

pub const DXGI_MODE_SCANLINE_ORDER = INT;
pub const DXGI_MODE_SCALING = INT;

pub const DXGI_RATIONAL = extern struct {
    Numerator: UINT,
    Denominator: UINT,
};

pub const DXGI_MODE_DESC = extern struct {
    Width: UINT,
    Height: UINT,
    RefreshRate: DXGI_RATIONAL,
    Format: DXGI_FORMAT,
    ScanlineOrdering: DXGI_MODE_SCANLINE_ORDER,
    Scaling: DXGI_MODE_SCALING,
};

pub const DXGI_SAMPLE_DESC = extern struct {
    Count: UINT,
    Quality: UINT,
};

pub const DXGI_SWAP_CHAIN_DESC = extern struct {
    BufferDesc: DXGI_MODE_DESC,
    SampleDesc: DXGI_SAMPLE_DESC,
    BufferUsage: DXGI_USAGE,
    BufferCount: UINT,
    OutputWindow: HWND,
    Windowed: BOOL,
    SwapEffect: DXGI_SWAP_EFFECT,
    Flags: UINT,
};

pub inline fn DXGI_ERROR_CODE(hr: HRESULT) DXGI_ERROR {
    return @enumFromInt(hr);
}

pub const UnexpectedError = error{
    Unexpected,
};

// tood: only print this error.Unexpected on Debug/ReleaseSafe
pub fn unexpectedError(dxgi_err: DXGI_ERROR) UnexpectedError {
    const tag_name = std.enums.tagName(DXGI_ERROR, dxgi_err) orelse "";
    std.debug.print("error.Unexpected: DXGI_ERROR({d}): {s}\n", .{
        @intFromEnum(dxgi_err),
        tag_name,
    });
    std.debug.dumpCurrentStackTrace(@returnAddress());
    return error.Unexpected;
}
