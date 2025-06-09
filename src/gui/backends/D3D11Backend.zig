const std = @import("std");
const windows = @import("../../windows.zig");
const shared = @import("../../gui/shared.zig");
const Backend = @import("../Backend.zig");
const mem = std.mem;
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const d3dcommon = windows.d3dcommon;
const d3dcompiler = windows.d3dcompiler;
const assert = std.debug.assert;

device_context: *d3d11.ID3D11DeviceContext,

render_target_view: *d3d11.ID3D11RenderTargetView,

vertex_shader: *d3d11.ID3D11VertexShader,
pixel_shader: *d3d11.ID3D11PixelShader,

input_layout: *d3d11.ID3D11InputLayout,
vertex_buffer: *d3d11.ID3D11Buffer,

const Self = @This();

const Vertex = extern struct {
    pos: [2]f32,
    color: [3]f32,
};

const DeviceContextState = struct {
    scissor_rects_len: windows.UINT = 0,
    viewports_len: windows.UINT = 0,
    scissor_rects: [d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]d3d11.D3D11_RECT = undefined,
    viewports: [d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE]d3d11.D3D11_VIEWPORT = undefined,
    rasterizer_state: ?*d3d11.ID3D11RasterizerState = null,
    blend_state: ?*d3d11.ID3D11BlendState = null,
    blend_factor: [4]windows.FLOAT = .{ 0.0, 0.0, 0.0, 0.0 },
    sample_mask: windows.UINT = 0,
    stencil_ref: windows.UINT = 0,
    render_target_view: ?*d3d11.ID3D11RenderTargetView = null,
    depth_stencil_view: ?*d3d11.ID3D11DepthStencilView = null, // todo: make it views there can be up to some d3d11 macro 8 i think
    depth_stencil_state: ?*d3d11.ID3D11DepthStencilState = null,
    shader_resource_view: ?*d3d11.ID3D11ShaderResourceView = null,
    sampler_state: ?*d3d11.ID3D11SamplerState = null,
    pixel_shader: ?*d3d11.ID3D11PixelShader = null,
    vertex_shader: ?*d3d11.ID3D11VertexShader = null,
    geometry_shader: ?*d3d11.ID3D11GeometryShader = null,
    pixel_shader_ins_len: windows.UINT = 0,
    vertex_shader_ins_len: windows.UINT = 0,
    geometry_shader_ins_len: windows.UINT = 0,
    pixel_shader_ins: [256]*d3d11.ID3D11ClassInstance = undefined,
    vertex_shader_ins: [256]*d3d11.ID3D11ClassInstance = undefined,
    geometry_shader_ins: [256]*d3d11.ID3D11ClassInstance = undefined,
    primative_topology: d3d11.D3D11_PRIMITIVE_TOPOLOGY = 0,
    index_buf: ?*d3d11.ID3D11Buffer = null,
    vertex_buf: ?*d3d11.ID3D11Buffer = null,
    constant_buf: ?*d3d11.ID3D11Buffer = null,
    index_buf_offset: windows.UINT = 0,
    vertex_buf_stride: windows.UINT = 0,
    vertex_buf_offset: windows.UINT = 0,
    index_buf_format: dxgi.DXGI_FORMAT = 0,
    input_layout: ?*d3d11.ID3D11InputLayout = null,
};

pub const Error = error{
    Unexpected,
};

pub fn init(swap_chain: *dxgi.IDXGISwapChain) Error!Self {
    const vs = @embedFile("../shaders/vs.hlsl");
    const ps = @embedFile("../shaders/ps.hlsl");

    var device: *d3d11.ID3D11Device = undefined;
    var device_context: *d3d11.ID3D11DeviceContext = undefined;

    var back_buffer: *d3d11.ID3D11Texture2D = undefined;

    var vertex_shader_blob: *d3dcommon.ID3DBlob = undefined;
    var pixel_shader_blob: *d3dcommon.ID3DBlob = undefined;

    try swap_chain.GetDevice(d3d11.ID3D11Device.UUID, @ptrCast(&device));
    defer device.Release();

    device.GetImmediateContext(&device_context);
    errdefer device_context.Release();

    var result = Self{
        .device_context = device_context,
        .render_target_view = undefined,
        .vertex_shader = undefined,
        .pixel_shader = undefined,
        .input_layout = undefined,
        .vertex_buffer = undefined,
    };

    try swap_chain.GetBuffer(0, d3d11.ID3D11Texture2D.UUID, @ptrCast(&back_buffer));
    defer back_buffer.Release();

    try device.CreateRenderTargetView(@ptrCast(back_buffer), null, &result.render_target_view);
    errdefer result.render_target_view.Release();

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

    try device.CreateBuffer(&vertex_buffer_desc, &vertex_buffer_initial, &result.vertex_buffer);
    errdefer result.vertex_buffer.Release();

    return result;
}

pub inline fn deinit(self: *const Self) void {
    D3D11Backend.deinit(self);
}

pub inline fn frame(self: *const Self, verticies: []const shared.DrawVertex, indecies: []const shared.DrawIndex) void {
    D3D11Backend.frame(self, verticies, indecies);
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

    fn deinit(context: *const anyopaque) void {
        const self: *const Self = @ptrCast(@alignCast(context));

        self.input_layout.Release();
        self.vertex_buffer.Release();

        self.vertex_shader.Release();
        self.pixel_shader.Release();

        self.render_target_view.Release();

        self.device_context.Release();
    }

    fn frame(context: *const anyopaque, verticies: []const shared.DrawVertex, indecies: []const shared.DrawIndex) void {
        // todo: pass this stuff into frame it self
        const self: *const Self = @ptrCast(@alignCast(context));

        var backup_state = DeviceContextState{};
        storeState(self.device_context, &backup_state);
        defer loadState(self.device_context, &backup_state);

        std.debug.print("{any}\n", .{verticies});
        std.debug.print("{d}\n", .{indecies});

        var offset: windows.UINT = 0;
        var stride: windows.UINT = @sizeOf(Vertex);

        self.device_context.IASetInputLayout(self.input_layout);
        self.device_context.IASetVertexBuffers(0, (&self.vertex_buffer)[0..1], (&stride)[0..1], (&offset)[0..1]);
        self.device_context.IASetPrimitiveTopology(d3d11.D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        self.device_context.VSSetShader(self.vertex_shader, null);
        self.device_context.PSSetShader(self.pixel_shader, null);

        self.device_context.OMSetRenderTargets((&self.render_target_view)[0..1], null);
        self.device_context.Draw(3, offset);
    }
};

fn storeState(context: *d3d11.ID3D11DeviceContext, state: *DeviceContextState) void {
    // todo: add OMGetRenderTargets
    state.scissor_rects_len = d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE;
    state.viewports_len = d3d11.D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE;
    state.pixel_shader_ins_len = 256;
    state.vertex_shader_ins_len = 256;
    state.geometry_shader_ins_len = 256;

    context.RSGetScissorRects(&state.scissor_rects_len, &state.scissor_rects);
    context.RSGetViewports(&state.viewports_len, &state.viewports);
    context.RSGetState(&state.rasterizer_state);
    context.OMGetBlendState(&state.blend_state, &state.blend_factor, &state.sample_mask);
    context.OMGetRenderTargets((&state.render_target_view)[0..1], &state.depth_stencil_view);
    context.OMGetDepthStencilState(&state.depth_stencil_state, &state.stencil_ref);
    context.PSGetShaderResources(0, (&state.shader_resource_view)[0..1]);
    context.PSGetSamplers(0, (&state.sampler_state)[0..1]);
    context.PSGetShader(&state.pixel_shader, &state.pixel_shader_ins, &state.pixel_shader_ins_len);
    context.VSGetShader(&state.vertex_shader, &state.vertex_shader_ins, &state.vertex_shader_ins_len);
    context.GSGetShader(&state.geometry_shader, &state.geometry_shader_ins, &state.geometry_shader_ins_len);
    context.VSGetConstantBuffers(0, (&state.constant_buf)[0..1]);
    context.IAGetPrimitiveTopology(&state.primative_topology);
    context.IAGetIndexBuffer(&state.index_buf, &state.index_buf_format, &state.index_buf_offset);
    context.IAGetVertexBuffers(0, (&state.vertex_buf)[0..1], (&state.vertex_buf_stride)[0..1], (&state.index_buf_offset)[0..1]);
    context.IAGetInputLayout(&state.input_layout);
}

fn loadState(context: *d3d11.ID3D11DeviceContext, state: *DeviceContextState) void {
    // RSSetScissorRects
    context.RSSetViewports(state.viewports[0..state.viewports_len]);
    // RSSetScissorRects
    // OMSetBlendState
    context.OMSetRenderTargets((&state.render_target_view)[0..1], state.depth_stencil_view);
    // OMSetDepthStencilState
    // PSSetShaderResources
    // PSSetSamplers()
    context.PSSetShader(state.pixel_shader, state.pixel_shader_ins[0..state.pixel_shader_ins_len]);
    context.VSSetShader(state.vertex_shader, state.vertex_shader_ins[0..state.vertex_shader_ins_len]);
    // GSSetShader
    context.IASetPrimitiveTopology(state.primative_topology);
    // IASetIndexBuffer
    context.IASetVertexBuffers(0, (&state.vertex_buf)[0..1], (&state.vertex_buf_stride)[0..1], (&state.vertex_buf_offset)[0..1]);
    // VSSetConstantBuffers
    context.IASetInputLayout(state.input_layout);

    defer releaseState(state);
}

fn releaseState(state: *DeviceContextState) void {
    const release = struct {
        fn inner(mb_ctx: ?*anyopaque) void {
            if (mb_ctx) |ctx| {
                const iunknown: *windows.IUnknown = @ptrCast(@alignCast(ctx));
                iunknown.Release();
            }
        }
    }.inner;

    release(state.rasterizer_state);
    release(state.blend_state);
    release(state.render_target_view);
    release(state.depth_stencil_view);
    release(state.depth_stencil_state);
    release(state.shader_resource_view);
    release(state.sampler_state);

    release(state.pixel_shader);
    for (0..state.pixel_shader_ins_len) |i| {
        state.pixel_shader_ins[i].Release();
    }

    release(state.vertex_shader);
    for (0..state.vertex_shader_ins_len) |i| {
        state.vertex_shader_ins[i].Release();
    }

    release(state.geometry_shader);
    for (0..state.geometry_shader_ins_len) |i| {
        state.geometry_shader_ins[i].Release();
    }

    release(state.index_buf);
    release(state.vertex_buf);
    release(state.constant_buf);
    release(state.input_layout);

    state.* = undefined;
}
