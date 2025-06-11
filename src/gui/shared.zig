const std = @import("std");

pub const DrawIndex = u16;

pub const DrawVertex = extern struct { pos: [2]f32, uv: [2]f32, col: u32 };

pub const ConstantBuffer = extern struct {
    mvp: [4][4]f32,
};
