const Image = @import("Image.zig");

pub const DrawIndex = u16;

pub const DrawCommand = struct {
    image: ?Image,
    index_len: DrawIndex,
    index_off: DrawIndex,
};

pub const DrawVertex = extern struct {
    pos: [2]f32,
    uv: [2]f32,
    col: u32,
    flags: u8 = 4,
};

pub const ConstantBuffer = extern struct {
    mvp: [4][4]f32,
};
