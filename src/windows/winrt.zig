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

pub const AsyncStatus = enum(INT) {
    Started = 0,
    Completed = 1,
    Canceled = 2,
    Error = 3,
};

// Expects allocator to be threadsafe
pub fn Callback(
    allocator: Allocator,
    context: anytype,
    comptime invokeFn: fn (@TypeOf(context), asyncInfo: *IAsyncInfo, status: AsyncStatus) IAsyncOperationCompletedHandler.InvokeError!void
) Allocator.Error!*IAsyncOperationCompletedHandler {
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

            // there are like runtime types GUIDs so we would like need to make IAsyncOperationCompletedHandler

            const refs = self.ref_count.load(.acquire);
            std.debug.print("refs: {d}, GUID: {x} {x} {x} {x}\n", .{refs, riid.Data1, riid.Data2, riid.Data3, riid.Data4});

            if (mem.eql(u8, mem.asBytes(riid), mem.asBytes(IUnknown.UUID))) {
                _ = self.ref_count.fetchAdd(1, .release);

                ppvObject.* = ctx;
                return windows.S_OK;
            }
            return windows.E_NOINTERFACE;
        }

        pub fn AddRef(ctx: *anyopaque) callconv(WINAPI) ULONG {
            std.debug.print("AddRef\n", .{});
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchAdd(1, .release);
            return prev + 1;
        }

        fn Release(ctx: *anyopaque) callconv(WINAPI) ULONG {
            std.debug.print("Release\n", .{});
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchSub(1, .acquire);

            if (prev == 1) {
                self.allocator.destroy(self);
            }

            return prev - 1;
        }

        pub fn Invoke(ctx: *anyopaque, asyncInfo: *IAsyncInfo, status: AsyncStatus) callconv(WINAPI) HRESULT {
            std.debug.print("Invoke\n", .{});
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
    };
}
