const std = @import("std");
const stb = @import("stb.zig");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Command = enum {
    curr,
    next,
    previous,
};

fn sendCommand(spotify: *Spotify, cmd: Command) !stb.Image {
    const allocator = spotify.http_client.allocator;

    switch (cmd) {
        .curr => {},
        .next => try spotify.skipToNext(),
        .previous => try spotify.skipToPrevious(),
    }

    const track = try spotify.getCurrentlyPlayingTrack();
    defer track.deinit();

    const uri = try std.Uri.parse(track.value.item.album.images[0].url);

    var server_header: [256]u8 = undefined;

    var req = try spotify.http_client.open(.GET, uri, .{
        .server_header_buffer = &server_header,
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    const image = try allocator.alloc(u8, req.response.content_length.?);
    defer allocator.free(image);

    try req.reader().readNoEof(image);

    return stb.loadImageFromMemory(image, .{
        .channels = .rgba,
    });
}

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client = try Client.init(allocator);
    defer client.deinit();

    // need to make this off main thread
    var spotify = Spotify{
        .http_client = &client,
        .authorization = "Bearer ...",
    };

    var action: SingleAction(sendCommand) = undefined;
    
    try action.init(allocator);
    defer action.deinit();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    // mb dont do it here
    const cover = blk: {
        const stb_image = try sendCommand(&spotify, .curr);
        defer stb_image.deinit();

        break :blk try hook.loadImage(allocator, .{
            .data = stb_image.data,
            .width = stb_image.width,
            .height = stb_image.height,
            .format = .rgba,
            .usage = .dynamic,
        });
    };
    defer cover.deinit(allocator);

    // Now we need to hook windoe proc and chill

    var i: u32 = 0;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        defer i +%= 1;

        if (action.dispatch()) |x| {
            const stb_image: stb.Image = try x;
            defer stb_image.deinit();

            hook.updateImage(cover, stb_image.data);
        }

        if (i % 1000 == 0) {
            assert(action.dispatched() == true);
            try action.post(.{&spotify, .curr});
        }

        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(cover.width), @floatFromInt(cover.height) }, cover);
        if (action.busy()) {
            gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        }
        gui.text(.{ 200.0, 200.0 }, "Helogjk", 0xFFFFFFFF, font);
    }
}

fn SingleAction(comptime func: anytype) type {
    return struct {
        allocator: Allocator,

        mutex: Thread.Mutex = .{},
        cond: Thread.Condition = .{},

        thread: Thread,
        is_running: bool = true,

        run_node: ?*Runnable = null,
        value: ?ReturnType = null,

        const Runnable = struct {
            runFn: *const fn (*Runnable) void,
        };

        const ReturnType = @typeInfo(@TypeOf(func)).@"fn".return_type.?;
        const Self = @This();

        pub fn init(self: *Self, allocator: Allocator) !void {
            self.* = .{
                .allocator = allocator,
                .thread = try Thread.spawn(.{}, worker, .{self}),
            };
        }

        pub fn deinit(self: *Self) void {
            {
                self.mutex.lock();
                defer self.mutex.unlock();

                self.is_running = false;
            }

            self.cond.broadcast();
            self.thread.join();
        }

        pub fn busy(self: *Self) bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.run_node != null and self.value == null;
        }

        pub fn dispatched(self: *Self) bool {
            self.mutex.lock();
            defer self.mutex.unlock();

            return self.run_node == null and self.value == null;
        }

        pub fn dispatch(self: *Self) ?ReturnType {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.run_node != null) {
                return null;
            }

            if (self.value == null) {
                return null;
            }

            const tmp = self.value.?;
            self.value = null;
            return tmp;
        }

        pub fn post(self: *Self, args: anytype) Allocator.Error!void {
            const Args = @TypeOf(args);
            const Closure = struct {
                args: Args,
                action: *Self,
                run_node: Runnable = .{ .runFn = runFn },

                fn runFn(runnable: *Runnable) void {
                    const closure: *@This() = @alignCast(@fieldParentPtr("run_node", runnable));

                    const is_running = blk: {
                        const mutex = &closure.action.mutex;
                        mutex.lock();
                        defer mutex.unlock();

                        break :blk closure.action.is_running;
                    };

                    const val: ?ReturnType = if (is_running) @call(.auto, func, closure.args) else null;

                    const mutex = &closure.action.mutex;
                    mutex.lock();
                    defer mutex.unlock();

                    closure.action.run_node = null;
                    closure.action.value = val;

                    closure.action.allocator.destroy(closure);
                }
            };

            {
                self.mutex.lock();
                defer self.mutex.unlock();

                assert(self.run_node == null);
                assert(self.value == null);

                const closure = try self.allocator.create(Closure);
                closure.* = .{
                    .args = args,
                    .action = self,
                };

                self.run_node = &closure.run_node;
            }

            self.cond.signal();
        }

        fn worker(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (true) {
                if (self.run_node) |run_node| {
                    self.mutex.unlock();
                    defer self.mutex.lock();

                    run_node.runFn(self.run_node.?);
                }

                if (self.is_running) {
                    self.cond.wait(&self.mutex);
                } else {
                    break;
                }
            }
        }
    };
}
