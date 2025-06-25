const std = @import("std");
const stb = @import("stb.zig");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

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

    var job_queue: JobQueue = undefined;

    try job_queue.init(allocator);
    defer job_queue.deinit();

    var skip_job: JobQueue.Job(Spotify.skipToNext) = .{};

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    try job_queue.spawn(&skip_job, .{&spotify});

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        if (skip_job.isCompleted()) |val| {
            try val;
        } else {
            std.debug.print("waiting...\n", .{});
        }

        gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        //gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(cover.image.width), @floatFromInt(cover.image.height) }, cover.image);

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

    fn Job(comptime Func: anytype) type {
        return struct {
            const ReturnType = @typeInfo(@TypeOf(Func)).@"fn".return_type.?;

            value: ?ReturnType  = null,
            is_completed: std.atomic.Value(bool) = .init(false),

            comptime func: @TypeOf(Func) = Func,

            pub fn isCompleted(self: *@This()) ?ReturnType {
                if (self.is_completed.load(.monotonic)) {
                    return self.value.?;
                } else {
                    return null;
                }
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

    fn spawn(self: *JobQueue, job: anytype, args: anytype) !void {
        assert(job.isCompleted() != null);
        job.value = null;
        job.is_completed.store(false, .monotonic);

        const ArgsType = @TypeOf(args);
        const JobType = @TypeOf(job);

        const Closure = struct {
            args: ArgsType,
            job: JobType,
            worker: *JobQueue,
            node: Queue.Node = .{ .data = .{ .runFn = runFn } },

            fn runFn(runnable: *Runnable) void {
                const node: *Queue.Node = @fieldParentPtr("data", runnable);
                const closure: *@This() = @alignCast(@fieldParentPtr("node", node));

                const result = @call(.auto, closure.job.func, closure.args);

                const mutex = &closure.worker.mutex;
                mutex.lock();
                defer mutex.unlock();


                closure.job.value = result;
                closure.job.is_completed.store(true, .monotonic);

                closure.worker.allocator.destroy(closure);
            }

        }; 

        {
            self.mutex.lock();
            defer self.mutex.unlock();

            const closure = try self.allocator.create(Closure);
            closure.* = .{
                .args = args,
                .job = job,
                .worker = self,
            };

            self.tasks.append(&closure.node);
        }

        self.cond.signal();
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
