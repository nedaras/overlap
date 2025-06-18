const std = @import("std");

pub const Header = extern struct {
    glyphs_len: u16,
    tex_width: u16,
    tex_height: u16,
};

pub const Glyph = extern struct {
    unicode: u32,
    width: u8,
    height: u8,
    bearing_x: i8,
    bearing_y: i8,
    advance: u8,
    off_x: u16,
    off_y: u16,
};
