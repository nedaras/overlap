const std = @import("std");
const Hook = @import("hook2.zig");
const hook = @import("hook.zig");
const gui = hook.gui;

// My solution of rendering fonts.
// We will have custom font format that will have bitmap fonts
// and just load it at runtime simple as that

var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
const allocator = da.allocator();

var font: hook.Font = undefined;
var file: std.fs.File = undefined;

// todo: add err handling for init
fn init() void {
    font = hook.loadFont(allocator, file) catch unreachable;
}

fn cleanup() void {
    font.deinit(allocator);
}

var x: f32 = 0.0;

fn frame() !void {
    gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
    // allow to pass multiple fonts, like fallback ones
    gui.text(.{ 200.0, 200.0 }, "Helo", font);
}

pub fn main() !void {
    defer _ = da.deinit();

    // This callback functions sucks
    // New idea make smth like hook.next()
    // and inside our like frame logic
    // this next would mean that we're doing rendering from our main thread
    // so err handling would work runtime sefety would work fs.cwd() would work, everything would work
    // i mean yee it prob will be a bit slower cuz we will have mutexes between this main thread and hooked Present thread
    // but it is worth it

    //file = try std.fs.cwd().openFile("font.fat", .{});
    //defer file.close();

    //try hook.run(@TypeOf(frame), .{
        //.frame_cb = &frame,
        //.init_cb = &init,
        //.cleanup_cb = &cleanup,
    //});

    // this is much more simpler just for now its kinda ugly

    var hook2 = try Hook.init();
    defer hook2.deinit();


    // init_cb

    while (true) {
        // frame_cb
        Hook.gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        try hook2.present();
    }

    // cleanup_cb
}
