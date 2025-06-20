const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const fat = @import("fat.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
const Image = @import("gui/Image.zig");
const Font = @import("gui/Font.zig");
const mem = std.mem;
const fs = std.fs;
const Thread = std.Thread;
const Allocator = mem.Allocator;

d3d11_hook: ?*D3D11Hook = null,

reset_event_a: Thread.ResetEvent = .{},
reset_event_b: Thread.ResetEvent = .{},

gui: Gui = .init,
exiting: bool = false,

const Self = @This();

// todo: just add zelf thingy cuz there should be only one hook tbf
pub fn attach(self: *Self) !void {
    const window = windows.GetForegroundWindow() orelse return error.NoWindow;

    try minhook.MH_Initialize();
    errdefer minhook.MH_Uninitialize() catch {};

    var d3d11_hook = try D3D11Hook.init(window, .{
        .frame_cb = &frame,
        .error_cb = &errored,
        .context = self,
    });
    errdefer d3d11_hook.deinit();

    self.reset_event_a.wait();

    self.d3d11_hook = d3d11_hook;
}

pub fn detach(self: *Self) void {
    self.exiting = true;
    self.reset_event_b.set();

    self.d3d11_hook.?.deinit();
    minhook.MH_Uninitialize() catch {};
}

pub fn newFrame(self: *Self) void {
    self.reset_event_a.wait();
}

pub fn endFrame(self: *Self) void {
    self.reset_event_a.reset();
    self.reset_event_b.set();
}

pub inline fn loadImage(self: *Self, allocator: Allocator, desc: Image.Desc) Image.Error!Image {
    return self.d3d11_hook.?.backend.?.backend().loadImage(allocator, desc);
}

pub fn loadFont(self: *Self, allocator: Allocator, sub_path: []const u8) !Font {
    const file = try fs.cwd().openFile(sub_path, .{});
    defer file.close();

    const reader = file.reader();
    const head = try reader.readStructEndian(fat.Header, .little);

    const glyphs = try allocator.alloc(fat.Glyph, head.glyphs_len);
    errdefer allocator.free(glyphs);

    try reader.readNoEof(mem.sliceAsBytes(glyphs));

    const texure = try allocator.alloc(u8, @as(usize, head.tex_width) * @as(usize, head.tex_height));
    defer allocator.free(texure);

    try reader.readNoEof(texure);

    const image = try self.loadImage(allocator, .{
        .width = @intCast(head.tex_width),
        .height = @intCast(head.tex_height),
        .format = .R,
        .data = texure,
    });
    errdefer image.deinit();

    return .{
        .glyphs = glyphs,
        .image = image,
    };
}

// hooked thread
fn errored(context: *anyopaque, err: D3D11Hook.Error) void {
    _ = context;
    err catch unreachable;
}

// hooked thread
// if false is returned frame will never be called again
fn frame(context: *anyopaque, backend: Backend) bool {
    const self: *Self = @ptrCast(@alignCast(context));

    self.reset_event_a.set();

    // now it waits even if we unhook cuz noone resets it
    self.reset_event_b.wait();
    self.reset_event_b.reset();

    if (self.exiting) {
        return false;
    }

    backend.frame(self.gui.draw_verticies.constSlice(), self.gui.draw_indecies.constSlice(), self.gui.draw_commands.constSlice());
    self.gui.clear();

    return true;
}
