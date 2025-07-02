const std = @import("std");
const windows = @import("../windows.zig");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;

const INT = windows.INT;
const GUID = windows.GUID;
const ULONG = windows.ULONG;
const REFIID = windows.REFIID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const IUnknown = windows.IUnknown;
const IMarshal = windows.IMarshal;
const IAgileObject = windows.IAgileObject;

pub const AsyncStatus = enum(INT) {
    Started = 0,
    Completed = 1,
    Canceled = 2,
    Error = 3,
};

// Expects allocator to be threadsafe
pub fn Callback(allocator: Allocator, context: anytype, comptime invokeFn: fn (@TypeOf(context), asyncInfo: *IAsyncInfo, status: AsyncStatus) IAsyncOperationCompletedHandler.InvokeError!void) Allocator.Error!*IAsyncOperationCompletedHandler {
    const Context = @TypeOf(context);

    const Closure = struct {
        vtable: *const IAsyncOperationCompletedHandlerVTable = &.{
            .QueryInterface = &QueryInterface,
            .AddRef = &AddRef,
            .Release = &Release,
            .Invoke = &Invoke,
        },

        allocator: Allocator,
        context: Context,

        ref_count: std.atomic.Value(ULONG),

        pub fn QueryInterface(ctx: *anyopaque, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const tmp_uuid = comptime &GUID.parse("{10f0074e-923d-5510-8f4a-dde37754ca0e}");
            const guids = &[_]windows.REFIID{
                tmp_uuid,
                IUnknown.UUID,
                IAgileObject.UUID,
            };

            if (windows.eqlGuids(riid, guids)) {
                _ = self.ref_count.fetchAdd(1, .release);

                ppvObject.* = ctx;
                return windows.S_OK;
            }

            if (mem.eql(u8, mem.asBytes(riid), mem.asBytes(IMarshal.UUID))) {
                @panic("marshal requested!");
            }

            return windows.E_NOINTERFACE;
        }

        pub fn AddRef(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchAdd(1, .release);
            return prev + 1;
        }

        fn Release(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchSub(1, .acquire);
            if (prev == 1) {
                self.allocator.destroy(self);
            }

            return prev - 1;
        }

        pub fn Invoke(ctx: *anyopaque, asyncInfo: *IAsyncInfo, status: AsyncStatus) callconv(WINAPI) HRESULT {
            const self: *@This() = @alignCast(@ptrCast(ctx));
            invokeFn(self.context, asyncInfo, status) catch |err| return switch (err) {
                error.OutOfMemory => windows.E_OUTOFMEMORY,
                error.Unexpected => windows.E_UNEXPECTED,
            };

            return windows.S_OK;
        }
    };

    if (@offsetOf(Closure, "vtable") != 0) {
        @compileError("COM interfaces 'vtable' argument must be set first");
    }

    const closure = try allocator.create(Closure);
    closure.* = .{
        .allocator = allocator,
        .context = context,
        .ref_count = .init(1),
    };

    return @ptrCast(closure);
}

pub const IAsyncOperationCompletedHandler = extern struct {
    vtable: *const IAsyncOperationCompletedHandlerVTable,

    pub inline fn Release(self: *IAsyncOperationCompletedHandler) void {
        _ = self.vtable.Release(self);
    }

    pub const InvokeError = error{
        OutOfMemory,
        Unexpected,
    };
};

pub const IAsyncOperationCompletedHandlerVTable = extern struct {
    QueryInterface: *const fn (*anyopaque, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT,
    AddRef: *const fn (*anyopaque) callconv(WINAPI) ULONG,
    Release: *const fn (*anyopaque) callconv(WINAPI) ULONG,
    Invoke: *const fn (*anyopaque, asyncInfo: *IAsyncInfo, status: AsyncStatus) callconv(WINAPI) HRESULT,
};

pub const IAsyncInfo = extern struct {
    vtable: [*]const *const anyopaque,

    /// __uuidof(IAsyncInfo) = `"00000036-0000-0000-C000-000000000046"`
    pub const UUID = &GUID{
        .Data1 = 0x00000036,
        .Data2 = 0x0000,
        .Data3 = 0x0000,
        .Data4 = .{
            0xC0, 0x00,
            0x00, 0x00,
            0x00, 0x00,
            0x00, 0x46,
        },
    };

    pub inline fn Release(self: *IAsyncInfo) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub fn get_Status(self: *IAsyncInfo) AsyncStatus {
        const FnType = fn (*IAsyncInfo, *AsyncStatus) callconv(WINAPI) HRESULT;
        const get_status: *const FnType = @ptrCast(self.vtable[7]);

        var val: AsyncStatus = undefined;
        assert(get_status(self, &val) == windows.S_OK);

        return val;
    }
};

pub fn IAsyncOperation(comptime T: type) type {
    return extern struct {
        vtable: [*]const *const anyopaque,

        const Self = @This();

        pub inline fn QueryInterface(self: *Self, riid: REFIID, ppvObject: **anyopaque) IUnknown.QueryInterfaceError!void {
            return IUnknown.QueryInterface(@ptrCast(self), riid, ppvObject);
        }

        pub const PutCompletedError = error{Unexpected};

        pub fn put_Completed(self: *Self, handler: *IAsyncOperationCompletedHandler) PutCompletedError!void {
            const FnType = fn (*Self, *IAsyncOperationCompletedHandler) callconv(WINAPI) HRESULT;
            const put_completed: *const FnType = @ptrCast(self.vtable[6]);

            const hr = put_completed(self, handler);
            return switch (hr) {
                windows.S_OK => {},
                else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
            };
        }

        pub const GetResultsError = error{Unexpected};

        pub fn GetResults(self: *Self) GetResultsError!T {
            const FnType = fn (*Self, *T) callconv(WINAPI) HRESULT;
            const get_results: *const FnType = @ptrCast(self.vtable[8]);

            var val: T = undefined;

            const hr = get_results(self, &val);
            return switch (hr) {
                windows.S_OK => val,
                else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
            };
        }

        pub fn get(self: *Self) !T {
            var async_info: *IAsyncInfo = undefined;

            try self.QueryInterface(IAsyncInfo.UUID, @ptrCast(&async_info));
            defer async_info.Release();

            if (async_info.get_Status() == .Completed) {
                return self.GetResults();
            }

            var reset_event: std.Thread.ResetEvent = .{};

            const Context = struct {
                reset_event: *std.Thread.ResetEvent,

                pub fn invoke(ctx: @This(), _: *IAsyncInfo, _: AsyncStatus) !void {
                    ctx.reset_event.set();
                }
            };

            // todo: idk get size of CLosure or idk
            var buf: [40]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buf);

            try self.put_Completed(Callback(fba.allocator(), Context{ .reset_event = &reset_event }, Context.invoke) catch unreachable);
            reset_event.wait();

            return switch (async_info.get_Status()) {
                .Started => unreachable,
                .Completed => self.GetResults(),
                .Error => error.UnhandledError,
                .Canceled => error.Canceled,
            };
        }
    };
}
