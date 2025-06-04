const std = @import("std");
const windows = std.os.windows;

const INT = windows.INT;

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
