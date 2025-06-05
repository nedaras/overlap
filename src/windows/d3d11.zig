const std = @import("std");
const dxgi = @import("dxgi.zig");
const d3dcommon = @import("d3dcommon.zig");
const windows = std.os.windows;

const GUID = windows.GUID;
const UINT = windows.UINT;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const HMODULE = windows.HMODULE;
const IDXGIAdapter = dxgi.IDXGIAdapter;
const IDXGISwapChain = dxgi.IDXGISwapChain;
const D3D_DRIVER_TYPE = d3dcommon.D3D_DRIVER_TYPE;
const DXGI_SWAP_CHAIN_DESC = dxgi.DXGI_SWAP_CHAIN_DESC;
const D3D_FEATURE_LEVEL = d3dcommon.D3D_FEATURE_LEVEL;

pub const D3D11_SDK_VERSION = 7;

pub const ID3D11Device = extern struct {
    vtable: [*]const *const anyopaque,

    /// __uuidof(ID3D11Device) = "db6f6ddb-ac77-4e88-8253-819df9bbf140"
    pub const UUID = &GUID{
        .Data1 = 0xdb6f6ddb,
        .Data2 = 0xac77,
        .Data3 = 0x4e88,
        .Data4 = .{
            0x82, 0x53,
            0x81, 0x9d, 0xf9, 0xbb, 0xf1, 0x40,
        },
    };

    pub inline fn Release(self: *ID3D11Device) void {
        const T = fn (*anyopaque) callconv(WINAPI) ULONG;
        const release: *const T = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

pub const ID3D11DeviceContext = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11DeviceContext) void {
        const T = fn (*anyopaque) callconv(WINAPI) ULONG;
        const release: *const T = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

pub extern "d3d11" fn D3D11CreateDeviceAndSwapChain(
    pAdapter: ?*IDXGIAdapter,
    DriverType: D3D_DRIVER_TYPE,
    Software: ?HMODULE,
    Flags: UINT,
    pFeatureLevels: ?[*]const D3D_FEATURE_LEVEL,
    FeatureLevels: UINT,
    SDKVersion: UINT,
    pSwapChainDesc: ?*const DXGI_SWAP_CHAIN_DESC,
    ppSwapChain: **IDXGISwapChain,
    ppDevice: **ID3D11Device,
    pFeatureLevel: ?*D3D_FEATURE_LEVEL,
    ppImmediateContext: **ID3D11DeviceContext,
) callconv(WINAPI) HRESULT;
