const std = @import("std");
const windows = @import("../../windows.zig");
const Image = @import("../Image.zig");
const mem = std.mem;
const dxgi = windows.dxgi;
const d3d11 = windows.d3d11;
const assert = std.debug.assert;
const Allocator = mem.Allocator;

allocator: Allocator,

texture: *d3d11.ID3D11Texture2D,
resource: *d3d11.ID3D11ShaderResourceView,

const Self = @This();

pub fn init(device: *d3d11.ID3D11Device, allocator: Allocator, desc: Image.Desc) Image.Error!*Self {
    assert(desc.width * desc.height == desc.data.len);

    var result = try allocator.create(Self);

    const dxgi_format = switch (desc.format) {
        .R8G8B8A8_UNORM => dxgi.DXGI_FORMAT_R8G8B8A8_UNORM,
    };

    var texture_desc = mem.zeroes(d3d11.D3D11_TEXTURE2D_DESC);
    texture_desc.Width = desc.width;
    texture_desc.Height = desc.height;
    texture_desc.MipLevels = 1;
    texture_desc.ArraySize = 1;
    texture_desc.Format = dxgi_format;
    texture_desc.SampleDesc.Count = 1;
    texture_desc.Usage = d3d11.D3D11_USAGE_DEFAULT;
    texture_desc.BindFlags = d3d11.D3D11_BIND_SHADER_RESOURCE;

    var initial_data = mem.zeroes(d3d11.D3D11_SUBRESOURCE_DATA);
    initial_data.pSysMem = desc.data.ptr;
    initial_data.SysMemPitch = desc.width * @intFromEnum(desc.format);

    try device.CreateTexture2D(&texture_desc, &initial_data, &result.texture);
    errdefer result.texture.Release();

    try device.CreateShaderResourceView(@ptrCast(result.texture), null, &result.resource);
    errdefer result.resource.Release();

    return result;
}

pub const vtable = Image.VTable{
    .deinit = &deinit,
};

fn deinit(context: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(context));

    self.resource.Release();
    self.texture.Release();

    self.allocator.destroy(self);
}
