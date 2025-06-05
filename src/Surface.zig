const std = @import("std");
const windows = @import("windows.zig");
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;

vertex_shader: *d3d11.ID3D11VertexShader,
pixel_shader: *d3d11.ID3D11PixelShader,

const Self = @This();

pub fn init(device: *d3d11.ID3D11Device, device_context: *d3d11.ID3D11DeviceContext) !Self {
    _ = device_context;

    const vs = @embedFile("shaders/vs.glsl");
    const ps = @embedFile("shaders/ps.glsl");

    var result = Self{
        .vertex_shader = undefined,
        .pixel_shader = undefined,
    };

    var vertex_shader_blob: *d3dcommon.ID3DBlob = undefined;
    var pixel_shader_blob: *d3dcommon.ID3DBlob = undefined;

    const hr_a = d3dcompiler.D3DCompile(vs.ptr, vs.len, null, null, null, "VS", "vs_5_0", 0, 0, &vertex_shader_blob, null);
    if (hr_a != windows.S_OK) {
        return error.Unexpected;
    }
    defer vertex_shader_blob.Release();

    const hr_b = d3dcompiler.D3DCompile(ps.ptr, ps.len, null, null, null, "PS", "ps_5_0", 0, 0, &pixel_shader_blob, null);
    if (hr_b != windows.S_OK) {
        return error.Unexpected;
    }
    defer pixel_shader_blob.Release();

    try device.CreateVertexShader(vertex_shader_blob.GetBufferPointer(), vertex_shader_blob.GetBufferSize(), null, &result.vertex_shader);
    errdefer result.vertex_shader.Release();

    try device.CreatePixelShader(pixel_shader_blob.GetBufferPointer(), pixel_shader_blob.GetBufferSize(), null, &result.pixel_shader);
    errdefer result.pixel_shader.Release();

    return result;
}

pub fn deinit(self: Self) void {
    self.vertex_shader.Release();
    self.vertex_shader.Release();
}
