const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Hook = @import("Hook.zig");
const time = std.time;
const Uri = std.Uri;
const assert = std.debug.assert;

const combase = @import("windows/combase.zig");

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    //const str = std.unicode.wtf8ToWtf16LeStringLiteral("Hello!");

    var hstr: combase.HSTRING = undefined;
    //_ = combase.WindowsCreateString(str, str.len, &hstr);

    _ = combase.RoGetActivationFactory(hstr, @import("windows.zig").d3d11.ID3D11Device.UUID, &hstr);

    var client = try Client.init(allocator);
    defer client.deinit();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    //const gui = hook.gui();
    //const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();
    }
}
