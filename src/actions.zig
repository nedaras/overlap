const std = @import("std");
const Thread = std.Thread;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

// Todo: add some tests here

pub fn SingleAction(comptime T: type) type {
    return struct {
        allocator: Allocator,

        mutex: Thread.Mutex = .{},
        cond: Thread.Condition = .{},

        thread: Thread,
        is_running: bool = true,

        run_node: ?*Runnable = null,
        value: ?T = null,

        const Runnable = struct {
            runFn: *const fn (*Runnable) void,
        };

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

        pub fn dispatch(self: *Self) ?T {
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

        pub fn post(self: *Self, comptime func: anytype, args: anytype) Allocator.Error!void {
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

                    const val: ?T = if (is_running) @call(.auto, func, closure.args) else null;

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

test SingleAction {
    std.debug.print("test\n", .{});
}
