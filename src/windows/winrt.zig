const std = @import("std");
const windows = @import("../windows.zig");
const mem = std.mem;
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const uuidOf = windows.uuidOf;
const signatureOf = windows.signatureOf;
const uuidFromSignature = windows.uuidFromSignature;

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

pub fn Callback(
    comptime UUID: REFIID,
    comptime Context: type,
    comptime invokeFn: fn (Context, asyncInfo: *IAsyncInfo, status: AsyncStatus) IAsyncOperationCompletedHandler.InvokeError!void,
) type {
    return struct {
        vtable: *const IAsyncOperationCompletedHandlerVTable = &.{
            .QueryInterface = &QueryInterface,
            .AddRef = &AddRef,
            .Release = &Release,
            .Invoke = &Invoke,
        },

        ref_count: std.atomic.Value(ULONG) = .init(0),

        context: Context,

        const Self = @This();

        // tbf we rly dont need to make new vtables for each subtype of Callback
        // check what zig does if it does not optimize this, we should just push our generic CallbackVTable

        comptime {
            if (@offsetOf(Self, "vtable") != 0) {
                @compileError("Callback's 'vtable' argument must be set to first");
            }

            //@compileLog(@offsetOf(Self, "ref_count"));
            //@compileLog(@sizeOf(std.atomic.Value(ULONG)));

            //if (@offsetOf(Self, "ref_count") != 4) {
            //@compileError("Callback's 'ref_count' argument must be set to second");
            //}
        }

        pub fn init(ctx: Context) Self {
            return .{ .context = ctx };
        }

        pub fn handler(self: *Self) *IAsyncOperationCompletedHandler {
            return @alignCast(@ptrCast(self));
        }

        pub fn QueryInterface(ctx: *anyopaque, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const guids = &[_]windows.REFIID{
                UUID,
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

        // todo: reusize this
        pub fn AddRef(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchAdd(1, .release);
            return prev + 1;
        }

        // todo: reusize this
        fn Release(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchSub(1, .acquire);
            std.debug.print("Callback refs: {d}\n", .{prev - 1});
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
}

pub fn Callback2(
    comptime TSender: type,
    comptime TResult: type,
    comptime Context: anytype,
    comptime invokeFn: fn (Context) IAsyncOperationCompletedHandler.InvokeError!void,
) type {
    return struct {
        vtable: *const TypedEventHandlerVTable(TSender, TResult) = &.{
            .QueryInterface = &QueryInterface,
            .AddRef = &AddRef,
            .Release = &Release,
            .Invoke = &Invoke,
        },

        ref_count: std.atomic.Value(ULONG) = .init(0),

        context: Context,

        const Self = @This();

        // tbf we rly dont need to make new vtables for each subtype of Callback
        // check what zig does if it does not optimize this, we should just push our generic CallbackVTable

        comptime {
            if (@offsetOf(Self, "vtable") != 0) {
                @compileError("Callback's 'vtable' argument must be set to first");
            }

            //@compileLog(@offsetOf(Self, "ref_count"));
            //@compileLog(@sizeOf(std.atomic.Value(ULONG)));

            //if (@offsetOf(Self, "ref_count") != 4) {
            //@compileError("Callback's 'ref_count' argument must be set to second");
            //}
        }

        pub fn init(ctx: Context) Self {
            return .{ .context = ctx };
        }

        pub fn handler(self: *Self) *TypedEventHandler(TSender, TResult) {
            return @alignCast(@ptrCast(self));
        }

        pub fn QueryInterface(ctx: *anyopaque, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const guids = &[_]windows.REFIID{
                uuidOf(TypedEventHandler(TSender, TResult)),
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

        // todo: reusize this
        pub fn AddRef(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchAdd(1, .release);
            return prev + 1;
        }

        // todo: reusize this
        fn Release(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchSub(1, .acquire);
            return prev - 1;
        }

        pub fn Invoke(ctx: *anyopaque, _: TSender, _: TResult) callconv(WINAPI) HRESULT {
            const self: *@This() = @alignCast(@ptrCast(ctx));
            invokeFn(self.context) catch |err| return switch (err) {
                error.OutOfMemory => windows.E_OUTOFMEMORY,
                error.Unexpected => windows.E_UNEXPECTED,
            };

            return windows.S_OK;
        }
    };
}

pub fn TypedEventHandler(comptime TSender: type, comptime TResult: type) type {
    return extern struct {
        vtable: *const TypedEventHandlerVTable(TSender, TResult),

        pub const SIGNATURE = "pinterface({9de1c534-6ae1-11e0-84e1-18a905bcc53f}"
            ++ ";"
            ++ signatureOf(TSender)
            ++ ";"
            ++ signatureOf(TResult) 
            ++ ")";

        pub const UUID = uuidFromSignature(SIGNATURE);
    };
}

pub fn TypedEventHandlerVTable(comptime TSender: type, comptime TResult: type) type {
    return extern struct {
        QueryInterface: *const fn (*anyopaque, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT,
        AddRef: *const fn (*anyopaque) callconv(WINAPI) ULONG,
        Release: *const fn (*anyopaque) callconv(WINAPI) ULONG,
        Invoke: *const fn (*anyopaque, sender: TSender, args: TResult) callconv(WINAPI) HRESULT,
    };
}

pub fn IAsyncOperationCompletedHandler(comptime TResult: type) type {
    return extern struct {
        vtable: *const IAsyncOperationCompletedHandlerVTable,

        pub const UUID = &GUID.parse("{fcdcf02c-e5d8-4478-915a-4d90b74b83a5}");

        pub inline fn Release(self: *IAsyncOperationCompletedHandler(TResult)) void {
            _ = self.vtable.Release(self);
        }

        pub const InvokeError = error{
            OutOfMemory,
            Unexpected,
        };
    };
}

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

    pub fn Close(self: *IAsyncInfo) void {
        const FnType = fn (*IAsyncInfo) callconv(WINAPI) HRESULT;
        const close: *const FnType = @ptrCast(self.vtable[10]);

        assert(close(self) == windows.S_OK);
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

        pub inline fn Release(self: *Self) void {
            IUnknown.Release(@ptrCast(self));
        }

        pub fn Close(self: *Self) void {
            var async_info: *IAsyncInfo = undefined;

            self.QueryInterface(IAsyncInfo.UUID, @ptrCast(&async_info)) catch unreachable;
            defer async_info.Release();

            async_info.Close();
        }

        pub fn put_Completed(self: *Self, handler: *IAsyncOperationCompletedHandler(T)) PutCompletedError!void {
            const FnType = fn (*Self, *IAsyncOperationCompletedHandler(T)) callconv(WINAPI) HRESULT;
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
