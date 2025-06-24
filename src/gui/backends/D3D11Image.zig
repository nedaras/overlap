const std = @import("std");
const windows = @import("../../windows.zig");
const Image = @import("../Image.zig");
const mem = std.mem;
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const assert = std.debug.assert;
const Allocator = mem.Allocator;
const Format = Image.Format;

texture: *d3d11.ID3D11Texture2D,
resource: *d3d11.ID3D11ShaderResourceView,

const Self = @This();

pub fn init(device: *d3d11.ID3D11Device, allocator: Allocator, desc: Image.Desc) Image.Error!*Self {
    assert(desc.width * desc.height * @intFromEnum(desc.format) == desc.data.len);

    var result = try allocator.create(Self);

    const format: windows.INT = switch (desc.format) {
        .r => dxgi.DXGI_FORMAT_R8_UNORM,
        .rgba => dxgi.DXGI_FORMAT_R8G8B8A8_UNORM,
    };
    
    const usage: windows.INT = switch (desc.usage) {
        .static => d3d11.D3D11_USAGE_DEFAULT,
        .dynamic => d3d11.D3D11_USAGE_DYNAMIC,
    };

    const cpu_flags: windows.UINT = switch (desc.usage) {
        .static => 0,
        .dynamic => d3d11.D3D11_CPU_ACCESS_WRITE,
    };

    var texture_desc = mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
    texture_desc.Width = desc.width;
    texture_desc.Height = desc.height;
    texture_desc.MipLevels = 1;
    texture_desc.ArraySize = 1;
    texture_desc.Format = format;
    texture_desc.SampleDesc.Count = 1;
    texture_desc.Usage = usage;
    texture_desc.BindFlags = d3d11.D3D11_BIND_SHADER_RESOURCE;
    texture_desc.CPUAccessFlags = cpu_flags;

    switch (desc.usage) {
        .static => {
            var initial_data = mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
            initial_data.pSysMem = desc.data.ptr;
            initial_data.SysMemPitch = desc.width * @intFromEnum(desc.format);

            try device.CreateTexture2D(&texture_desc, &initial_data, &result.texture);
            errdefer result.texture.Release();
        },
        .dynamic => {
            try device.CreateTexture2D(&texture_desc, null, &result.texture);
            errdefer result.texture.Release();

            var device_context: *d3d11.ID3D11DeviceContext = undefined;
            var mapped_resource: d3d11.D3D11_MAPPED_SUBRESOURCE = undefined;

            device.GetImmediateContext(&device_context);
            defer device_context.Release();

            try device_context.Map(@ptrCast(result.texture), 0, d3d11.D3D11_MAP_WRITE_DISCARD, 0, &mapped_resource);
            defer device_context.Unmap(@ptrCast(result.texture), 0);

            mapped_resource.write(u8, desc.data);
        },
    }

    errdefer result.texture.Release();

    try device.CreateShaderResourceView(@ptrCast(result.texture), null, &result.resource);
    errdefer result.resource.Release();

    return result;
}

pub const vtable = Image.VTable{
    .deinit = &deinit,
};

fn deinit(context: *anyopaque, allocator: Allocator) void {
    const self: *Self = @ptrCast(@alignCast(context));

    self.resource.Release();
    self.texture.Release();

    allocator.destroy(self);
}
