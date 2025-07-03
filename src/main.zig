const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Hook = @import("Hook.zig");
const time = std.time;
const unicode = std.unicode;
const Uri = std.Uri;
const assert = std.debug.assert;

const windows = @import("windows.zig");

// idk seems so many async stuff can happen here these controls then winhttp stuff
// I do not rly see a point for multiple threads perhaps single thread can handle this all
// except if that jpeg to img will be cpu intensive then yee...

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    _ = allocator;

    // todo: use WindowsCreateStringReference
    // todo: we need to Release() this stuff

    // we could hide all of this in my own like GlobalSystemMediaTransportControlsSessionManager zig friendly class as cpp does
    const class = try windows.WindowsCreateString(
        unicode.wtf8ToWtf16LeStringLiteral("Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager"),
    );
    defer windows.WindowsDeleteString(class);

    var s_manager: *windows.media.IGlobalSystemMediaTransportControlsSessionManagerStatics = undefined;

    try windows.RoGetActivationFactory(
        class,
        windows.media.IGlobalSystemMediaTransportControlsSessionManagerStatics.UUID,
        @ptrCast(&s_manager),
    );
    defer s_manager.Release();

    const a_manager = try s_manager.RequestAsync();
    defer a_manager.Close();
    defer a_manager.Release();

    const manager = try a_manager.get();
    defer manager.Release();

    const session = (try manager.GetCurrentSession()).?;
    defer session.Release();

    const a_sesion = try session.TryGetMediaPropertiesAsync();
    defer a_sesion.Close();
    defer a_sesion.Release();

    const props = try a_sesion.get();
    defer props.Release();

    const title = windows.WindowsGetStringRawBuffer(try props.get_Title());

    std.debug.print("{s}\n", .{std.mem.sliceAsBytes(title)});

    //while (info.get_Status() == .Started) {
    //std.atomic.spinLoopHint();
    //}

    //std.debug.print("{}\n", .{info.get_Status()});
    //const session = try (try future.GetResults()).GetCurrentSession(); // unsafe as maybe its canceled or stauts is err

    //var info2: *windows.IAsyncInfo = undefined;
    //const future2 = try session.?.TryGetMediaPropertiesAsync();

    //try future2.QueryInterface(windows.IAsyncInfo.UUID, @ptrCast(&info2));

    //while (info2.get_Status() == .Started) {
    //std.atomic.spinLoopHint();
    //}

    //std.debug.print("{}\n", .{info2.get_Status()});

    //const props = try future2.GetResults();
    //const title = try props.get_Title();

    //const wstr = windows.WindowsGetStringRawBuffer(title);
    //std.debug.print("{s}\n", .{std.mem.sliceAsBytes(wstr)});

    //var hook: Hook = .init;

    //try hook.attach();
    //defer hook.detach();

    //const gui = hook.gui();
    //const input = hook.input();

    //const font = try hook.loadFont(allocator, "font.fat");
    //defer font.deinit(allocator);

    //while (true) {
    //try hook.newFrame();
    //defer hook.endFrame();
    //}
}
