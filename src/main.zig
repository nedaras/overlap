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

fn sendCommand(allocator: Allocator, spotify: *Spotify, cmd: Command) !stb.Image {
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
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client = try Client.init(allocator);
    defer client.deinit();

    // need to make this off main thread
    var spotify = Spotify{
        .http_client = &client,
        .authorization = "Bearer ...",
    };

    var jq : JobQueue = undefined;

    try jq.init(allocator);
    defer jq.deinit();

    var task = try jq.spawn(sendCommand, .{allocator, &spotify, .curr});
    defer task.deinit();

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    while (!task.isCompleted()) {
        std.debug.print("working\n", .{});
    }

    (try task.resolve()).deinit();

    var i: u32 = 0;

    //var cover: ?Hook.Image = null;
    //defer if (cover) |img| img.deinit(allocator);

    while (i != 3000) {
        try hook.newFrame();
        defer hook.endFrame();

        i +%= 1;

        // stupid we should be allowed to stack them
        //if (cmd_job.isResolved()) {
            //if (i % 1000 == 0) {
                //try jq.spawn(&cmd_job, .{allocator, &spotify, .next});
            //}
        //}

        // isResolvable

        //if (cmd_job.isCompleted()) {
            //const stb_image: stb.Image = try cmd_job.resolve();
            //defer stb_image.deinit();

            //if (cover) |img| {
                //hook.updateImage(img, stb_image.data);
            //} else {
                //cover = try hook.loadImage(allocator, .{
                    //.data = stb_image.data,
                    //.width = stb_image.width,
                    //.height = stb_image.height,
                    //.format = .rgba,
                    //.usage = .dynamic,
                //});
            //}
        //}

        //gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        //if (cover) |img| {
            //gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(img.width), @floatFromInt(img.height) }, img);
        //}

        gui.text(.{ 200.0, 200.0 }, "Helogjk", 0xFFFFFFFF, font);
    }
}

const JobQueue = struct {
    allocator: Allocator,

    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    thread: ?std.Thread = null,

    tasks: Queue = .{},

    is_running: bool = true,

    const Queue = std.DoublyLinkedList(Runnable);
    const Runnable = struct {
        runFn: *const fn (*Runnable) void,
    };

    fn Task(comptime Func: type) type {
        return struct {
            const ReturnType = @typeInfo(Func).@"fn".return_type.?;

            /// Should never be accessed without a `mutex`.
            value: ?ReturnType = null,
            deinitFn: *const fn(*@This()) void,

            mutex: Thread.Mutex = .{},

            pub inline fn deinit(task: *@This()) void {
                task.deinitFn(task);
            }

            pub fn isCompleted(task: *@This()) bool {
                task.mutex.lock();
                defer task.mutex.unlock();

                return task.value != null;
            }

            pub fn resolve(self: *@This()) ReturnType {
                while (!isCompleted(self)) {
                    std.atomic.spinLoopHint();
                }

                return self.value.?;
            }
        };
    }

    fn init(self: *JobQueue, allocator: Allocator) !void {
        self.* = .{
            .allocator = allocator,
            .thread = try std.Thread.spawn(.{}, worker, .{self}),
        };
    }

    fn deinit(self: *JobQueue) void {
        if (self.thread) |thread| {
            {
                self.mutex.lock();
                defer self.mutex.unlock();

                self.is_running = false;
            }

            self.cond.broadcast();
            thread.join();
        }

        self.* = undefined;
    }

    fn spawn(self: *JobQueue, comptime func: anytype, args: anytype) !*Task(@TypeOf(func)) {
        const Args = @TypeOf(args);
        const Func = @TypeOf(func);

        const Closure = struct {
            args: Args,
            job_queue: *JobQueue,
            task: Task(Func) = .{ .deinitFn = deinitFn },
            node: Queue.Node = .{ .data = .{ .runFn = runFn } },

            fn runFn(runnable: *Runnable) void {
                const node: *Queue.Node = @fieldParentPtr("data", runnable);
                const closure: *@This() = @alignCast(@fieldParentPtr("node", node));

                const val = @call(.auto, func, closure.args);

                const mutex = &closure.task.mutex;
                mutex.lock();
                defer mutex.unlock();

                closure.task.value = val;
            }

            fn deinitFn(task: *Task(Func)) void {
                const closure: *@This() = @alignCast(@fieldParentPtr("task", task));

                const mutex = &closure.job_queue.mutex;
                mutex.lock();
                defer mutex.unlock();

                closure.job_queue.allocator.destroy(closure);
            }
        }; 

        self.mutex.lock();
        errdefer self.mutex.unlock();

        const closure = try self.allocator.create(Closure);
        closure.* = .{
            .args = args,
            .job_queue = self,
        };

        self.tasks.append(&closure.node);

        self.mutex.unlock();
        self.cond.signal();

        return &closure.task;
    }

    fn worker(self: *JobQueue) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (true) {
            if (self.tasks.popFirst()) |node| {
                self.mutex.unlock();
                defer self.mutex.lock();

                node.data.runFn(&node.data);
            }

            if (self.is_running) {
                self.cond.wait(&self.mutex);
            } else {
                break;
            }
        }
    }

};
