const std = @import("std");
const windows = @import("windows.zig");
const minhook = @import("minhook.zig");
const fat = @import("fat.zig");
const Gui = @import("Gui.zig");
const Backend = @import("gui/Backend.zig");
const D3D11Hook = @import("hooks/D3D11Hook.zig");
pub const Image = @import("gui/Image.zig");
const Font = @import("gui/Font.zig");
const mem = std.mem;
const fs = std.fs;
const Thread = std.Thread;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

// todo: fix some race conditions

const Gateway = struct {
    gui: Gui,

    main_reset_event: Thread.ResetEvent,
    hooked_reset_event: Thread.ResetEvent,

    err: ?FrameError,
    exiting: bool,
};

d3d11_hook: ?*D3D11Hook = null,
gateway: Gateway,

const Self = @This();

pub const init = Self{
    .d3d11_hook = null,
    .gateway = .{
        .gui = .init,
        .main_reset_event = .{},
        .hooked_reset_event = .{},
        .err = null,
        .exiting = false,
    },
};

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

    try newFrame(self);
    assert(d3d11_hook.backend != null);

    self.d3d11_hook = d3d11_hook;
}

pub fn detach(self: *Self) void {
    self.gateway.exiting = true;
    self.gateway.hooked_reset_event.set();

    // this line will bring some problems
    self.d3d11_hook.?.deinit();
    minhook.MH_Uninitialize() catch {};
}

pub inline fn gui(self: *Self) *Gui {
    return &self.gateway.gui;
}

pub const FrameError = D3D11Hook.Error;

pub fn newFrame(self: *Self) FrameError!void {
    self.gateway.main_reset_event.wait();
    if (self.gateway.err) |err| {
        @branchHint(.cold);
        return err;
    }
}

pub fn endFrame(self: *Self) void {
    self.gateway.main_reset_event.reset();
    self.gateway.hooked_reset_event.set();
}

pub inline fn loadImage(self: *Self, allocator: Allocator, desc: Image.Desc) Image.Error!Image {
    // todo: idk???
    return self.d3d11_hook.?.backend.?.backend().loadImage(allocator, desc);
}

pub inline fn updateImage(self: *Self, image: Image, bytes: []const u8) void {
    // todo: idk???
    self.d3d11_hook.?.backend.?.backend().updateImage(image, bytes);
}

pub fn loadFont(self: *Self, allocator: Allocator, sub_path: []const u8) !Font {
    // todo: add like check if fat file is fat idk
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
        .format = .r,
        .data = texure,
    });
    errdefer image.deinit();

    return .{
        .glyphs = glyphs,
        .image = image,
    };
}

// hooked thread
// only after this call backend becomes invalid
fn errored(context: *anyopaque, err: D3D11Hook.Error) void {
    const self: *Self = @ptrCast(@alignCast(context));

    assert(self.gateway.err == null);

    self.gateway.err = err;
    self.gateway.main_reset_event.set();
}

// hooked thread
// if false is returned frame will never be called again
// ok this backend is kinda useless, cuz it should never be null
// and it is null only if resize buffers fails, if so errored gets called that would mean that yee backend will be invalid!!
// and we should return error anyway sooo idk
fn frame(context: *anyopaque, backend: Backend) bool {
    const self: *Self = @ptrCast(@alignCast(context));

    assert(self.gateway.err == null);
    self.gateway.main_reset_event.set();

    self.gateway.hooked_reset_event.wait();
    self.gateway.hooked_reset_event.reset();

    if (self.gateway.exiting) {
        return false;
    }

    const shared_gui = self.gui();
    defer shared_gui.clear();

    backend.frame(
        shared_gui.draw_verticies.constSlice(),
        shared_gui.draw_indecies.constSlice(),
        shared_gui.draw_commands.constSlice(),
    );

    return true;
}
