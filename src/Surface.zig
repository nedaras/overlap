const std = @import("std");
const windows = @import("windows.zig");
const mem = std.mem;
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;

const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,
};

input_layout: *d3d11.ID3D11InputLayout,
vertex_buffer: *d3d11.ID3D11Buffer,

vertex_shader: *d3d11.ID3D11VertexShader,
pixel_shader: *d3d11.ID3D11PixelShader,


const Self = @This();

// Idea is to have like one Surface api and have multiple backends d3d opengl vulkan
pub fn init(device: *d3d11.ID3D11Device) !Self {
    const vs = @embedFile("shaders/vs.glsl");
    const ps = @embedFile("shaders/ps.glsl");

    var result = Self{
        .input_layout = undefined,
        .vertex_buffer = undefined,
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

    try device.CreateVertexShader(vertex_shader_blob.slice(), null, &result.vertex_shader);
    errdefer result.vertex_shader.Release();

    try device.CreatePixelShader(pixel_shader_blob.slice(), null, &result.pixel_shader);
    errdefer result.pixel_shader.Release();

    const input_elements = &[_]d3d11.D3D11_INPUT_ELEMENT_DESC{
        .{
            .SemanticName = "POSITION",
            .SemanticIndex = 0,
            .Format = dxgi.DXGI_FORMAT_R32G32_FLOAT,
            .InputSlot = 0,
            .AlignedByteOffset = 0,
            .InputSlotClass = d3d11.D3D11_INPUT_PER_VERTEX_DATA,
            .InstanceDataStepRate = 0,
        },
        .{
            .SemanticName = "COLOR",
            .SemanticIndex = 0,
            .Format = dxgi.DXGI_FORMAT_R32G32B32_FLOAT,
            .InputSlot = 0,
            .AlignedByteOffset = 8,
            .InputSlotClass = d3d11.D3D11_INPUT_PER_VERTEX_DATA,
            .InstanceDataStepRate = 0,
        },
    };

    try device.CreateInputLayout(input_elements, vertex_shader_blob.slice(), &result.input_layout);
    errdefer result.input_layout.Release();

    const verticies = &[_]Vertex{
        .{ .pos = .{ 0.0,  0.5 }, .color = .{ 1.0, 0.0, 0.0 } }, // Top (red)
        .{ .pos = .{ 0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 } }, // Right (green)
        .{ .pos = .{ -0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 } }, // Left (blue)
    };

    var vertex_buffer = mem.zeroes(d3d11.D3D11_BUFFER_DESC);
    vertex_buffer.Usage = d3d11.D3D11_USAGE_DEFAULT;
    vertex_buffer.ByteWidth = verticies.len * @sizeOf(Vertex);
    vertex_buffer.BindFlags = d3d11.D3D11_BIND_VERTEX_BUFFER;
    vertex_buffer.StructureByteStride = @sizeOf(Vertex);

    var vertex_buffer_initial = mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
    vertex_buffer_initial.pSysMem = verticies;

    try device.CreateBuffer(&vertex_buffer, &vertex_buffer_initial, &result.vertex_buffer);
    errdefer result.vertex_buffer.Release();

    return result;
}

pub fn deinit(self: Self) void {
    self.vertex_buffer.Release();
    self.input_layout.Release();

    self.vertex_shader.Release();
    self.vertex_shader.Release();
}

pub fn render(self: Self, device_context: *d3d11.ID3D11DeviceContext) !void {
    _ = self;
    std.debug.print("ID3D11DeviceContext*: {}\n", .{device_context});
}
