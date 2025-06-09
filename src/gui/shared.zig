const std = @import("std");

pub const DrawIndex = u16;

pub const DrawVertex = extern struct {
    pos: [2]f32,
    col: u32,
};
