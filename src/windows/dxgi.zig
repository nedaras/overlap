const std = @import("std");
const windows = @import("../windows.zig");

pub const d3d11 = @import("d3d11.zig");
pub const DXGI_ERROR = @import("dxgi_err.zig").DXGI_ERROR;

const INT = windows.INT;
const S_OK = windows.S_OK;
const HWND = windows.HWND;
const BOOL = windows.BOOL;
const UINT = windows.UINT;
const ULONG = windows.ULONG;
const HRESULT = windows.HRESULT;
const WINAPI = windows.WINAPI;
const REFIID = windows.REFIID;

pub const IDXGIAdapter = *opaque {};

pub const DXGI_FORMAT = INT;
pub const DXGI_FORMAT_R32G32B32_FLOAT = 6;
pub const DXGI_FORMAT_R32G32_FLOAT = 16;
pub const DXGI_FORMAT_R8G8B8A8_UNORM = 28;
pub const DXGI_FORMAT_R32_UINT = 42;
pub const DXGI_FORMAT_R16_UINT = 57;
pub const DXGI_FORMAT_R8_UNORM = 61;
pub const DXGI_FORMAT_R8_UINT = 62;

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

pub const IDXGISwapChain = extern struct {
    vtable: *const [18]*const anyopaque,

    pub inline fn AddRef(self: *IDXGISwapChain) void {
        const FnType = fn (*IDXGISwapChain) callconv(WINAPI) ULONG;
        const add_ref: *const FnType = @ptrCast(self.vtable[1]);

        _ = add_ref(self);
    }

    pub inline fn Release(self: *IDXGISwapChain) void {
        const FnType = fn (*IDXGISwapChain) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }

    pub const GetDeviceError = error{Unexpected};

    pub fn GetDevice(
        self: *IDXGISwapChain,
        riid: REFIID,
        ppDevice: **anyopaque,
    ) GetDeviceError!void {
        const FnType = fn (*IDXGISwapChain, REFIID, **anyopaque) callconv(WINAPI) HRESULT;
        const get_device: *const FnType = @ptrCast(self.vtable[7]);

        const hr = get_device(self, riid, ppDevice);
        return switch (DXGI_ERROR_CODE(hr)) {
            .SUCCESS => {},
            else => |err| unexpectedError(err),
        };
    }

    pub const GetBufferError = error{Unexpected};

    pub fn GetBuffer(
        self: *IDXGISwapChain,
        Buffer: UINT,
        riid: REFIID,
        ppSurface: **anyopaque,
    ) GetBufferError!void {
        const FnType = fn (*IDXGISwapChain, UINT, REFIID, **anyopaque) callconv(WINAPI) HRESULT;
        const get_buffer: *const FnType = @ptrCast(self.vtable[9]);

        const hr = get_buffer(self, Buffer, riid, ppSurface);
        return switch (DXGI_ERROR_CODE(hr)) {
            .SUCCESS => {},
            else => |err| unexpectedError(err),
        };
    }
};

pub inline fn DXGI_ERROR_CODE(hr: HRESULT) DXGI_ERROR {
    return @enumFromInt(hr);
}

pub const UnexpectedError = error{
    Unexpected,
};

// tood: only print this error.Unexpected on Debug/ReleaseSafe
pub fn unexpectedError(dxgi_err: DXGI_ERROR) UnexpectedError {
    if (std.posix.unexpected_error_tracing) {
        const tag_name = std.enums.tagName(DXGI_ERROR, dxgi_err) orelse "";
        std.debug.print("error.Unexpected: DXGI_ERROR({d}): {s}\n", .{
            @intFromEnum(dxgi_err),
            tag_name,
        });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}
