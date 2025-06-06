const std = @import("std");
const dxgi = @import("dxgi.zig");
const d3dcommon = @import("d3dcommon.zig");
const windows = std.os.windows;

pub const D3D11_ERROR = @import("d3d11_err.zig").D3D11_ERROR;

const INT = windows.INT;
const GUID = windows.GUID;
const UINT = windows.UINT;
const ULONG = windows.ULONG;
const FLOAT = windows.FLOAT;
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
const D3D_PRIMITIVE_TOPOLOGY = d3dcommon.D3D_PRIMITIVE_TOPOLOGY;

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
pub const ID3D11ClassInstance = *opaque{};
pub const ID3D11Resource = *opaque{};
pub const ID3D11DepthStencilView = *opaque{};

pub const D3D11_RENDER_TARGET_VIEW_DESC = opaque{};

pub const D3D11_VIEWPORT = extern struct {
    TopLeftX: FLOAT,
    TopLeftY: FLOAT,
    Width: FLOAT,
    Height: FLOAT,
    MinDepth: FLOAT,
    MaxDepth: FLOAT,
};

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


pub const ID3D11RenderTargetView = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3D11RenderTargetView) void {
        const FnType = fn (*ID3D11RenderTargetView) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
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

pub const ID3D11Texture2D = extern struct {
    vtable: [*]const *const anyopaque,

    /// __uuidof(ID3D11Device) = `"6f15aaf2-d208-4e89-9ab4-489535d34f9c"`
    pub const UUID = &GUID{
        .Data1 = 0x6f15aaf2,
        .Data2 = 0xd208,
        .Data3 = 0x4e89,
        .Data4 = .{
            0x9a, 0xb4,
            0x48, 0x95, 0x35, 0xd3, 0x4f, 0x9c,
        },
    };

    pub inline fn Release(self: *ID3D11Texture2D) void {
        const FnType = fn (*ID3D11Texture2D) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }
};

pub const ID3D11Device = extern struct {
    vtable: [*]const *const anyopaque,

    /// __uuidof(ID3D11Device) = `"db6f6ddb-ac77-4e88-8253-819df9bbf140"`
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

    pub const CreateRenderTargetViewError = error{Unexpected};

    pub fn CreateRenderTargetView(
        self: *ID3D11Device,
        pResource: *ID3D11Resource,
        pDesc: ?*const D3D11_RENDER_TARGET_VIEW_DESC,
        ppRTView: **ID3D11RenderTargetView,
    ) CreateRenderTargetViewError!void {
        const FnType = fn (*ID3D11Device, *ID3D11Resource, ?*const D3D11_RENDER_TARGET_VIEW_DESC, ?**ID3D11RenderTargetView) callconv(WINAPI) HRESULT;
        const create_render_target_view: *const FnType = @ptrCast(self.vtable[9]);

        const hr = create_render_target_view(self, pResource, pDesc, ppRTView);
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

    // 0 -> 7

    pub inline fn PSSetShader(
        self: *ID3D11DeviceContext,
        pPixelShader: *ID3D11PixelShader,
        ClassInstances: ?[]const *const ID3D11ClassInstance,
    ) void {
        const FnType = fn (*ID3D11DeviceContext, *ID3D11PixelShader, ?[*]const *const ID3D11ClassInstance, UINT) callconv(WINAPI) void;
        const vs_set_shader: *const FnType = @ptrCast(self.vtable[9]);

        const class_instance_ptr = if (ClassInstances) |ci| ci.ptr else null;
        const class_instances_len = if (ClassInstances) |ci| ci.len else 0;

        vs_set_shader(self, pPixelShader, class_instance_ptr, @intCast(class_instances_len));
    }
    
    pub inline fn VSSetShader(
        self: *ID3D11DeviceContext,
        pVertexShader: *ID3D11VertexShader,
        ClassInstances: ?[]const *const ID3D11ClassInstance,
    ) void {
        const FnType = fn (*ID3D11DeviceContext, *ID3D11VertexShader, ?[*]const *const ID3D11ClassInstance, UINT) callconv(WINAPI) void;
        const vs_set_shader: *const FnType = @ptrCast(self.vtable[11]);

        const class_instance_ptr = if (ClassInstances) |ci| ci.ptr else null;
        const class_instances_len = if (ClassInstances) |ci| ci.len else 0;

        vs_set_shader(self, pVertexShader, class_instance_ptr, @intCast(class_instances_len));
    }

    pub inline fn Draw(
        self: *ID3D11DeviceContext,
        VertexCount: UINT,
        StartVertexLocation: UINT,
    ) void {
        const FnType = fn (*ID3D11DeviceContext, UINT, UINT) callconv(WINAPI) void;
        const draw: *const FnType = @ptrCast(self.vtable[13]);

        draw(self, VertexCount, StartVertexLocation);
    }
    
    pub inline fn IASetInputLayout(self: *ID3D11DeviceContext, pInputLayout: *ID3D11InputLayout) void {
        const FnType = fn (*ID3D11DeviceContext, *ID3D11InputLayout) callconv(WINAPI) void;
        const ia_set_input_layout: *const FnType = @ptrCast(self.vtable[17]);

        ia_set_input_layout(self, pInputLayout);
    }

    pub inline fn IASetVertexBuffers(
        self: *ID3D11DeviceContext,
        StartSlot: UINT,
        VertexBuffers: []const ID3D11Buffer,
        pStrides: *UINT,
        pOffsets: *UINT,
    ) void {
        const FnType = fn (*ID3D11DeviceContext, UINT, UINT, [*]const ID3D11Buffer, *UINT, *UINT) callconv(WINAPI) void;
        const ia_set_input_vertex_buffers: *const FnType = @ptrCast(self.vtable[18]);

        ia_set_input_vertex_buffers(self, StartSlot, @intCast(VertexBuffers.len), VertexBuffers.ptr, pStrides, pOffsets);
    }

    pub inline fn IASetPrimitiveTopology(self: *ID3D11DeviceContext, Topology: D3D_PRIMITIVE_TOPOLOGY) void {
        const FnType = fn (*ID3D11DeviceContext, D3D_PRIMITIVE_TOPOLOGY) callconv(WINAPI) void;
        const ia_set_primitive_topology: *const FnType = @ptrCast(self.vtable[24]);

        ia_set_primitive_topology(self, Topology);
    }

    pub inline fn OMSetRenderTargets(
        self: *ID3D11DeviceContext,
        RenderTargetViews: []const *const ID3D11RenderTargetView,
        pDepthStencilView: ?*ID3D11DepthStencilView,
    ) void {
        const FnType = fn (*ID3D11DeviceContext, UINT, [*]const *const ID3D11RenderTargetView, ?*ID3D11DepthStencilView) callconv(WINAPI) void;
        const om_set_render_targets: *const FnType = @ptrCast(self.vtable[33]);

        om_set_render_targets(self, @intCast(RenderTargetViews.len), RenderTargetViews.ptr, pDepthStencilView);
    }

    pub inline fn RSSetViewports(self: *ID3D11DeviceContext, Viewports: []const D3D11_VIEWPORT) void {
        const FnType = fn (*ID3D11DeviceContext, UINT, [*]const D3D11_VIEWPORT) callconv(WINAPI) void;
        const rs_set_viewports: *const FnType = @ptrCast(self.vtable[44]);

        rs_set_viewports(self, @intCast(Viewports.len), Viewports.ptr);
    }

    pub inline fn ClearRenderTargetView(
        self: *ID3D11DeviceContext,
        pRenderTargetView: *ID3D11RenderTargetView,
        ColorRGBA: [4]f32,
    ) void {
        const FnType = fn (*ID3D11DeviceContext, *ID3D11RenderTargetView, *const [4]f32) callconv(WINAPI) void;
        const clear_render_target_view: *const FnType = @ptrCast(self.vtable[50]);

        clear_render_target_view(self, pRenderTargetView, &ColorRGBA);
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
