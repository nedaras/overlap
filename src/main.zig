const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Hook = @import("Hook.zig");
const time = std.time;
const unicode = std.unicode;
const windows = @import("windows.zig");
const media = windows.media;
const Uri = std.Uri;
const assert = std.debug.assert;

// todos: Make Player class so i would not need to look at windows
//        Read album image
//        hook to track change and session chnage events

pub fn main() !void {
    // we're doing smth bad with releases closes as we get crashes when cleaning up

    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    try windows.RoInitialize(windows.RO_INIT_MULTITHREADED);
    defer windows.RoUninitialize();

    // mybe move this media to just windows
    const session = try (try media.GlobalSystemMediaTransportControlsSessionManager.RequestAsync()).getAndForget(allocator);
    std.debug.print("{}\n", .{session});

    // todo: use WindowsCreateStringReference

    // we could hide all of this in my own like GlobalSystemMediaTransportControlsSessionManager zig friendly class as cpp does
    //const class = try windows.WindowsCreateString(
        //unicode.wtf8ToWtf16LeStringLiteral("Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager"),
    //);
    //defer windows.WindowsDeleteString(class);

    //var s_manager: *windows.media.IGlobalSystemMediaTransportControlsSessionManagerStatics = undefined;

    //try windows.RoGetActivationFactory(
        //class,
        //windows.media.IGlobalSystemMediaTransportControlsSessionManagerStatics.UUID,
        //@ptrCast(&s_manager),
    //);
    //defer s_manager.Release();

    //const a_manager = try s_manager.RequestAsync();
    //defer a_manager.Release();
    //defer a_manager.Close();

    //const manager = try a_manager.get();
    //defer manager.Release();

    //const session = (try manager.GetCurrentSession()).?;
    //defer session.Release();

    // now this sucks we prob could do like TypedEvent(..., ...).callback({}, invokeFn)
    // then to get like raw call .handler to cast it

    //var callback: windows.Callback2(
        //*windows.media.IGlobalSystemMediaTransportControlsSession,
        //*windows.media.IMediaPropertiesChangedEventArgs,
        //void,
        //struct {
            //fn invoke(_: void) !void {
                //std.debug.print("invoked!\n", .{});
            //}
        //}.invoke,
    //) = .init({});

    //_ = try session.add_MediaPropertiesChanged(callback.handler());
    // prob we need to rem after we're done

    //const a_props = try session.TryGetMediaPropertiesAsync();
    //defer a_props.Release();
    //defer a_props.Close();

    //const props = try a_props.get();
    //defer props.Release();

    //const w_title = windows.WindowsGetStringRawBuffer(try props.get_Title());
    //const w_artist = windows.WindowsGetStringRawBuffer(try props.get_Artist());

    //const title = try unicode.wtf16LeToWtf8Alloc(allocator, w_title);
    //defer allocator.free(title);

    //const artist = try unicode.wtf16LeToWtf8Alloc(allocator, w_artist);
    //defer allocator.free(artist);

    // for thumbnail we can use BitmapDecoder will not even need stb

    //std.debug.print("title: {s}\n", .{title});
    //std.debug.print("artist: {s}\n", .{artist});

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
