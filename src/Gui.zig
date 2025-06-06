pub const Backend = @import("gui/Backend.zig");

backend: Backend,

const Gui = @This();

pub fn deinit(self: Gui) void {
    self.backend.deinit();
}
