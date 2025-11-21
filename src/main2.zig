const Gui = @import("Gui2.zig");

pub fn init() void {
}

pub fn deinit() void {
}

pub fn render(gui: *Gui) void {
    gui.rect(.{ 0.0, 0.0 }, .{ 100.0, 100.0 }, 0xFFFFFFFF);
}
