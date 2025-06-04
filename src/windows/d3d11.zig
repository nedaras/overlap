const std = @import("std");
const dxgi = @import("dxgi.zig");
const d3dcommon = @import("d3dcommon.zig");
const windows = std.os.windows;

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

    pub inline fn Release(self: *ID3D11Device) ULONG {
        const T = fn (*anyopaque) callconv(WINAPI) ULONG;
        const release: *const T = @ptrCast(self.vtable[2]);

        return release(self);
    }
};

pub const ID3D11DeviceContext = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11DeviceContext) ULONG {
        const T = fn (*anyopaque) callconv(WINAPI) ULONG;
        const release: *const T = @ptrCast(self.vtable[2]);

        return release(self);
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
    ppSwapChain: ?**IDXGISwapChain,
    ppDevice: ?**ID3D11Device,
    pFeatureLevel: ?*D3D_FEATURE_LEVEL,
    ppImmediateContext: ?**ID3D11DeviceContext,
) callconv(WINAPI) HRESULT;
