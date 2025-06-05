const std = @import("std");
const windows = std.os.windows;

const INT = windows.INT;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const LPVOID = windows.LPVOID;
const SIZE_T = windows.SIZE_T;

pub const ID3DBlob = extern struct {
    vtable: [*]const *const anyopaque,

    pub inline fn Release(self: *ID3DBlob) void {
        const FnType = fn (*ID3DBlob) callconv(WINAPI) ULONG;
        const release: *const FnType = @ptrCast(self.vtable[2]);

        _ = release(self);
    }

    pub inline fn GetBufferPointer(self: *ID3DBlob) LPVOID {
        const FnType = fn (*ID3DBlob) callconv(WINAPI) LPVOID;
        const get_buffer_pointer: *const FnType = @ptrCast(self.vtable[3]);

        return get_buffer_pointer(self);
    }

    pub inline fn GetBufferSize(self: *ID3DBlob) SIZE_T {
        const FnType = fn (*ID3DBlob) callconv(WINAPI) SIZE_T ;
        const get_buffer_size: *const FnType = @ptrCast(self.vtable[4]);

        return get_buffer_size(self);
    }
};

pub const D3D_FEATURE_LEVEL = INT;
pub const D3D_FEATURE_LEVEL_9_1 = 0x9100;
pub const D3D_FEATURE_LEVEL_9_2 = 0x9200;
pub const D3D_FEATURE_LEVEL_9_3 = 0x9300;
pub const D3D_FEATURE_LEVEL_10_0 = 0xA000;
pub const D3D_FEATURE_LEVEL_10_1 = 0xA100;
pub const D3D_FEATURE_LEVEL_11_0 = 0xB000;
pub const D3D_FEATURE_LEVEL_11_1 = 0xB100;
pub const D3D_FEATURE_LEVEL_12_0 = 0xC000;
pub const D3D_FEATURE_LEVEL_12_1 = 0xC100;
pub const D3D_FEATURE_LEVEL_12_2 = 0xC200;

pub const D3D_DRIVER_TYPE = INT;
pub const D3D_DRIVER_TYPE_HARDWARE = 1;
