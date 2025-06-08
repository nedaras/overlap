pub const Backend = @import("gui/Backend.zig");

backend: Backend,

const Gui = @This();

pub const DrawVertex = extern struct {
    pos: [3]f32,
    uv: [2]f32,
    col: u32,
};

pub fn deinit(self: Gui) void {
    self.backend.deinit();
}
