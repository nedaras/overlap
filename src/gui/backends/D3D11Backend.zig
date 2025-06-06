const std = @import("std");
const windows = @import("../../windows.zig");
const Backend = @import("../Backend.zig");
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;

device_context: *d3d11.ID3D11DeviceContext,

vertex_shader: *d3d11.ID3D11VertexShader,
pixel_shader: *d3d11.ID3D11PixelShader,

const Self = @This();

pub fn init(swap_chain: *dxgi.IDXGISwapChain) !Self {
    var device: *d3d11.ID3D11Device = undefined;

    var vertex_shader_blob: *d3dcommon.ID3DBlob = undefined;
    var pixel_shader_blob: *d3dcommon.ID3DBlob = undefined;

    try swap_chain.GetDevice(d3d11.ID3D11Device.UUID, @ptrCast(&device));
    defer device.Release();

    var result = Self{
        .device_context = undefined,
        .vertex_shader = undefined,
        .pixel_shader = undefined,
    };

    device.GetImmediateContext(&result.device_context);

    const vs = @embedFile("../shaders/vs.hlsl");
    const ps = @embedFile("../shaders/ps.hlsl");

    const hr_a = d3dcompiler.D3DCompile(vs.ptr, vs.len, null, null, null, "VS", "vs_5_0", 0, 0, &vertex_shader_blob, null);
    switch (d3d11.D3D11_ERROR_CODE(hr_a)) {
        .S_OK => {},
        else => |err| return d3d11.unexpectedError(err),
    }
    defer vertex_shader_blob.Release();

    const hr_b = d3dcompiler.D3DCompile(ps.ptr, ps.len, null, null, null, "PS", "ps_5_0", 0, 0, &pixel_shader_blob, null);
    switch (d3d11.D3D11_ERROR_CODE(hr_b)) {
        .S_OK => {},
        else => |err| return d3d11.unexpectedError(err),
    }
    defer pixel_shader_blob.Release();

    try device.CreateVertexShader(vertex_shader_blob.slice(), null, &result.vertex_shader);
    errdefer result.vertex_shader.Release();

    try device.CreatePixelShader(pixel_shader_blob.slice(), null, &result.pixel_shader);
    errdefer result.pixel_shader.Release();

    return result;
}

pub inline fn deinit(self: *const Self) void {
    D3D11Backend.deinit(self);
}

pub inline fn frame(self: *const Self) void {
    D3D11Backend.frame(self);
}

pub inline fn backend(self: *const Self) Backend {
    return .{
        .ptr = self,
        .vtable = &D3D11Backend.vtable,
    };
}

const D3D11Backend = struct {
   pub const vtable  = Backend.VTable{
        .deinit = &D3D11Backend.deinit,
        .frame = &D3D11Backend.frame,
    };

    fn deinit(context: *const anyopaque) void {
        const self: *const Self = @ptrCast(@alignCast(context));

        self.vertex_shader.Release();
        self.pixel_shader.Release();

        self.device_context.Release();
    }

    fn frame(context: *const anyopaque) void {
        const self: *const Self = @ptrCast(@alignCast(context));
        _ = self;
    }
};
