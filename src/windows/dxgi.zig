const std = @import("std");
const windows = std.os.windows;

pub const d3d11 = @import("d3d11.zig");

const INT = windows.INT;
const UINT = windows.UINT;
const HWND = windows.HWND;
const BOOL = windows.BOOL;

pub const IDXGISwapChain = *opaque{};
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
