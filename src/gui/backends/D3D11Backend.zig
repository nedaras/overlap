const std = @import("std");
const windows = @import("../../windows.zig");
const mem = std.mem;
const Backend = @import("../Backend.zig");
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;

swap_chain: *dxgi.IDXGISwapChain,
device: *d3d11.ID3D11Device,
device_context: *d3d11.ID3D11DeviceContext,

render_target_view: ?*d3d11.ID3D11RenderTargetView = null,

input_layout: ?*d3d11.ID3D11InputLayout = null,
vertex_buffer: ?*d3d11.ID3D11Buffer = null,

vertex_shader: ?*d3d11.ID3D11VertexShader = null,
pixel_shader: ?*d3d11.ID3D11PixelShader = null,

const Self = @This();

const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,
};

pub const Error = error{
    Unexpected,
};

pub fn init(swap_chain: *dxgi.IDXGISwapChain) Error!Self {
    var device: *d3d11.ID3D11Device = undefined;
    var device_context: *d3d11.ID3D11DeviceContext = undefined;

    swap_chain.AddRef();
    errdefer swap_chain.Release();

    try swap_chain.GetDevice(d3d11.ID3D11Device.UUID, @ptrCast(&device));
    errdefer device.Release();

    device.GetImmediateContext(&device_context);
    errdefer device_context.Release();

    var result = Self{
        .swap_chain = swap_chain,
        .device = device,
        .device_context = device_context,
    };

    try createObjects(&result);

    return result;
}

pub fn createObjects(self: *Self) Error!void {
    var vertex_shader_blob: *d3dcommon.ID3DBlob = undefined;
    var pixel_shader_blob: *d3dcommon.ID3DBlob = undefined;

    var render_target_view: *d3d11.ID3D11RenderTargetView = undefined;

    var vertex_shader: *d3d11.ID3D11VertexShader = undefined;
    var pixel_shader: *d3d11.ID3D11PixelShader = undefined;

    var input_layout: *d3d11.ID3D11InputLayout = undefined;
    var vertex_buffer: *d3d11.ID3D11Buffer = undefined;

    const vs = @embedFile("../shaders/vs.hlsl");
    const ps = @embedFile("../shaders/ps.hlsl");

    var back_buffer: *d3d11.ID3D11Texture2D = undefined;

    try self.swap_chain.GetBuffer(0, d3d11.ID3D11Texture2D.UUID, @ptrCast(&back_buffer));
    defer back_buffer.Release();

    try self.device.CreateRenderTargetView(@ptrCast(back_buffer), null, &render_target_view);
    errdefer render_target_view.Release();

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

    try self.device.CreateVertexShader(vertex_shader_blob.slice(), null, &vertex_shader);
    errdefer vertex_shader.Release();

    try self.device.CreatePixelShader(pixel_shader_blob.slice(), null, &pixel_shader);
    errdefer pixel_shader.Release();

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

    try self.device.CreateInputLayout(input_elements, vertex_shader_blob.slice(), &input_layout);
    errdefer input_layout.Release();

    const verticies = &[_]Vertex{
        .{ .pos = .{ 0.0, 0.5 }, .color = .{ 1.0, 0.0, 0.0 } }, // Top (red)
        .{ .pos = .{ 0.5, -0.5 }, .color = .{ 0.0, 1.0, 0.0 } }, // Right (green)
        .{ .pos = .{ -0.5, -0.5 }, .color = .{ 0.0, 0.0, 1.0 } }, // Left (blue)
    };

    var vertex_buffer_desc = mem.zeroes(d3d11.D3D11_BUFFER_DESC);
    vertex_buffer_desc.Usage = d3d11.D3D11_USAGE_DEFAULT;
    vertex_buffer_desc.ByteWidth = verticies.len * @sizeOf(Vertex);
    vertex_buffer_desc.BindFlags = d3d11.D3D11_BIND_VERTEX_BUFFER;
    vertex_buffer_desc.StructureByteStride = @sizeOf(Vertex);

    var vertex_buffer_initial = mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
    vertex_buffer_initial.pSysMem = verticies;

    try self.device.CreateBuffer(&vertex_buffer_desc, &vertex_buffer_initial, &vertex_buffer);
    errdefer vertex_buffer.Release();

    self.render_target_view = render_target_view;
    self.vertex_shader = vertex_shader;
    self.pixel_shader = pixel_shader;
    self.input_layout = input_layout;
    self.vertex_buffer = vertex_buffer;
}

pub fn removeObjects(self: *Self) void {
    if (self.input_layout) |input_layout| {
        input_layout.Release();
        self.input_layout = null;
    }

    if (self.vertex_buffer) |vertex_buffer| {
        vertex_buffer.Release();
        self.vertex_buffer = null;
    }

    if (self.vertex_shader) |vertex_shader| {
        vertex_shader.Release();
        self.vertex_shader = null;
    }

    if (self.pixel_shader) |pixel_shader| {
        pixel_shader.Release();
        self.pixel_shader = null;
    }

    if (self.render_target_view) |render_target_view| {
        render_target_view.Release();
        self.render_target_view = null;
    }
}

pub inline fn deinit(self: *Self) void {
    D3D11Backend.deinit(self);
}

pub inline fn frame(self: *const Self) void {
    D3D11Backend.frame(self);
}

pub fn backend(self: *Self) Backend {
    return .{
        .ptr = self,
        .vtable = &D3D11Backend.vtable,
    };
}

const D3D11Backend = struct {
    pub const vtable = Backend.VTable{
        .deinit = &D3D11Backend.deinit,
        .frame = &D3D11Backend.frame,
    };

    fn deinit(context: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(context));

        removeObjects(self);

        self.device_context.Release();
        self.device.Release();
        self.swap_chain.Release();
    }

    fn frame(context: *const anyopaque) void {
        const self: *const Self = @ptrCast(@alignCast(context));

        var offset: windows.UINT = 0;
        var stride: windows.UINT = @sizeOf(Vertex);

        self.device_context.IASetInputLayout(self.input_layout.?);
        self.device_context.IASetVertexBuffers(0, (&self.vertex_buffer.?)[0..1], &stride, &offset);
        self.device_context.IASetPrimitiveTopology(d3dcommon.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        self.device_context.VSSetShader(self.vertex_shader.?, null);
        self.device_context.PSSetShader(self.pixel_shader.?, null);

        self.device_context.OMSetRenderTargets((&self.render_target_view.?)[0..1], null);
        self.device_context.Draw(3, offset);
    }
};
