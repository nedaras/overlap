const std = @import("std");
const dxgi = @import("dxgi.zig");
const d3dcommon = @import("d3dcommon.zig");
const windows = std.os.windows;

pub const D3D11_ERROR = @import("d3d11_err.zig").D3D11_ERROR;

const INT = windows.INT;
const GUID = windows.GUID;
const UINT = windows.UINT;
const ULONG = windows.ULONG;
const SIZE_T = windows.SIZE_T;
const LPCSTR = windows.LPCSTR;
const WINAPI = windows.WINAPI;
const LPCVOID = windows.LPCVOID;
const HRESULT = windows.HRESULT;
const HMODULE = windows.HMODULE;
const DXGI_FORMAT = dxgi.DXGI_FORMAT;
const IDXGIAdapter = dxgi.IDXGIAdapter;
const IDXGISwapChain = dxgi.IDXGISwapChain;
const D3D_DRIVER_TYPE = d3dcommon.D3D_DRIVER_TYPE;
const DXGI_SWAP_CHAIN_DESC = dxgi.DXGI_SWAP_CHAIN_DESC;
const D3D_FEATURE_LEVEL = d3dcommon.D3D_FEATURE_LEVEL;

pub const D3D11_SDK_VERSION = 7;

pub const D3D11_BIND_VERTEX_BUFFER = 1;

pub const D3D11_INPUT_CLASSIFICATION = INT;
pub const D3D11_INPUT_PER_VERTEX_DATA = 0;
pub const D3D11_INPUT_PER_INSTANCE_DATA = 1;

pub const D3D11_USAGE = INT;
pub const D3D11_USAGE_DEFAULT = 0;
pub const D3D11_USAGE_IMMUTABLE = 1;
pub const D3D11_USAGE_DYNAMIC = 2;
pub const D3D11_USAGE_STAGING = 3;

pub const ID3D11ClassLinkage = *opaque{};

pub const D3D11_INPUT_ELEMENT_DESC = extern struct {
    SemanticName: LPCSTR,
    SemanticIndex: UINT,
    Format: DXGI_FORMAT,
    InputSlot: UINT,
    AlignedByteOffset: UINT,
    InputSlotClass: D3D11_INPUT_CLASSIFICATION,
    InstanceDataStepRate: UINT,
};

pub const D3D11_BUFFER_DESC = extern struct {
    ByteWidth: UINT,
    Usage: D3D11_USAGE,
    BindFlags: UINT,
    CPUAccessFlags: UINT,
    MiscFlags: UINT,
    StructureByteStride: UINT,
};

pub const D3D11_SUBRESOURCE_DATA = extern struct {
    pSysMem: LPCVOID,
    SysMemPitch: UINT,
    SysMemSlicePitch: UINT,
};

pub const ID3D11Buffer = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11Buffer) void {
        const FnType = fn (*ID3D11Buffer) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

pub const ID3D11InputLayout = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11InputLayout) void {
        const FnType = fn (*ID3D11InputLayout) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

pub const ID3D11VertexShader = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11VertexShader) void {
        const FnType = fn (*ID3D11VertexShader) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

pub const ID3D11PixelShader = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11PixelShader) void {
        const FnType = fn (*ID3D11PixelShader) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

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
        const FnType = fn (*ID3D11Device) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }

    pub const CreateBufferError = error{Unexpected};

    pub fn CreateBuffer(
        self: *ID3D11Device,
        pDesc: *D3D11_BUFFER_DESC,
        pInitialData: ?*const D3D11_SUBRESOURCE_DATA,
        ppBuffer: **ID3D11Buffer,
    ) CreateBufferError!void {
        const FnType = fn (*ID3D11Device, *D3D11_BUFFER_DESC, ?*const D3D11_SUBRESOURCE_DATA, ?**ID3D11Buffer) callconv(WINAPI) HRESULT;
        const create_buffer: *const FnType = @ptrCast(self.vtable[3]);

        const hr = create_buffer(self, pDesc, pInitialData, ppBuffer);
        return switch (D3D11_ERROR_CODE(hr)) {
            .S_OK => {},
            else => |err| unexpectedError(err),
        };
    }

    pub const CreateInputLayoutError = error{Unexpected};

    pub fn CreateInputLayout(
        self: *ID3D11Device,
        InputElementDescs: []const D3D11_INPUT_ELEMENT_DESC,
        ShaderBytecodeWithInputSignature: []const u8,
        ppInputLayout: ?**ID3D11InputLayout,
    ) !void {
        const FnType = fn (*ID3D11Device, [*]const D3D11_INPUT_ELEMENT_DESC, SIZE_T, [*]const u8, SIZE_T, ?**ID3D11InputLayout) callconv(WINAPI) HRESULT;
        const create_input_layout: *const FnType = @ptrCast(self.vtable[11]);

        const hr = create_input_layout(self, InputElementDescs.ptr, InputElementDescs.len, ShaderBytecodeWithInputSignature.ptr, ShaderBytecodeWithInputSignature.len, ppInputLayout);
        return switch (D3D11_ERROR_CODE(hr)) {
            .S_OK => {},
            else => |err| unexpectedError(err),
        };
    }

    pub const CreateShaderError = error{Unexpected};

    pub fn CreateVertexShader(
        self: *ID3D11Device,
        ShaderBytecode: []const u8,
        pClassLinkage: ?*ID3D11ClassLinkage,
        ppVertexShader: **ID3D11VertexShader,
    ) CreateShaderError!void {
        const FnType = fn (*ID3D11Device, LPCVOID, SIZE_T, ?*ID3D11ClassLinkage, **ID3D11VertexShader) callconv(WINAPI) HRESULT;
        const create_vertex_shader: *const FnType = @ptrCast(self.vtable[12]);

        const hr = create_vertex_shader(self, ShaderBytecode.ptr, ShaderBytecode.len, pClassLinkage, ppVertexShader);
        return switch (D3D11_ERROR_CODE(hr)) {
            .S_OK => {},
            else => |err| unexpectedError(err),
        };
    }

    pub fn CreatePixelShader(
        self: *ID3D11Device,
        ShaderBytecode: []const u8,
        pClassLinkage: ?*ID3D11ClassLinkage,
        ppPixelShader: **ID3D11PixelShader,
    ) CreateShaderError!void {
        const FnType = fn (*ID3D11Device, LPCVOID, SIZE_T, ?*ID3D11ClassLinkage, **ID3D11PixelShader) callconv(WINAPI) HRESULT;
        const create_pixel_shader: *const FnType = @ptrCast(self.vtable[15]);

        const hr = create_pixel_shader(self, ShaderBytecode.ptr, ShaderBytecode.len, pClassLinkage, ppPixelShader);
        return switch (D3D11_ERROR_CODE(hr)) {
            .S_OK => {},
            else => |err| unexpectedError(err),
        };
    }

    pub inline fn GetImmediateContext(self: *ID3D11Device, ppImmediateContext: **ID3D11DeviceContext) void {
        const FnType = fn (*ID3D11Device, **ID3D11DeviceContext) callconv(WINAPI) void;
        const get_immediate_context: *const FnType = @ptrCast(self.vtable[40]);

        get_immediate_context(self, ppImmediateContext);
    }

};

pub const ID3D11DeviceContext = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11DeviceContext) void {
        const FnType = fn (*ID3D11DeviceContext) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

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

pub inline fn D3D11_ERROR_CODE(hr: HRESULT) D3D11_ERROR {
    return @enumFromInt(hr);
}

pub const UnexpectedError = error{
    Unexpected,
};

// tood: only print this error.Unexpected on Debug/ReleaseSafe
pub fn unexpectedError(d3d11_err: D3D11_ERROR) UnexpectedError {
    const tag_name = std.enums.tagName(D3D11_ERROR, d3d11_err) orelse "";
    std.debug.print("error.Unexpected: DXGI_ERROR({d}): {s}\n", .{
        @intFromEnum(d3d11_err),
        tag_name,
    });
    std.debug.dumpCurrentStackTrace(@returnAddress());
    return error.Unexpected;
}
