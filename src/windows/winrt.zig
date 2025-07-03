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
            _ = AddRef(self);
            return @alignCast(@ptrCast(self));
        }

        pub fn QueryInterface(ctx: *anyopaque, riid: REFIID, ppvObject: **anyopaque) callconv(WINAPI) HRESULT {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            std.debug.print("{x}-{x}-{x}-{x}\n", .{riid.Data1, riid.Data2, riid.Data3, riid.Data4});

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

        pub fn AddRef(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchAdd(1, .release);
            return prev + 1;
        }

        fn Release(ctx: *anyopaque) callconv(WINAPI) ULONG {
            const self: *@This() = @alignCast(@ptrCast(ctx));

            const prev = self.ref_count.fetchSub(1, .acquire);
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

pub const IAsyncOperationCompletedHandler = extern struct {
    vtable: *const IAsyncOperationCompletedHandlerVTable,

    pub const UUID = &GUID.parse("{fcdcf02c-e5d8-4478-915a-4d90b74b83a5}");

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

            const UUID = comptime blk: {
                @setEvalBranchQuota(10_000);
                const prefix = &[_]u8{0x11, 0xf4, 0x7a, 0xd5, 0x7b, 0x73, 0x42, 0xc0, 0xab, 0xae, 0x87, 0x8b, 0x1e, 0x16, 0xad, 0xee};

                //const sign = @import("./media.zig").IGlobalSystemMediaTransportControlsSessionManager.SIGNATURE;
                const signature = "pinterface({fcdcf02c-e5d8-4478-915a-4d90b74b83a5};" ++ std.meta.Child(T).SIGNATURE ++ ")";

                const data = prefix ++ signature;

                var hashed: [20]u8 = undefined;
                std.crypto.hash.Sha1.hash(data, &hashed, .{});

                const data1 = mem.readInt(u32, hashed[0..4], .big);
                const data2 = mem.readInt(u16, hashed[4..6], .big);

                const data3 = (mem.readInt(u16, hashed[6..8], .big) & 0x0fff) | (5 << 12);
                const data4 = ([1]u8{(hashed[8] & 0x3f) | 0x80} ++ hashed[9..16]).*;

                break :blk &GUID{
                    .Data1 = data1,
                    .Data2 = data2,
                    .Data3 = data3,
                    .Data4 = data4,
                };
            };

            //@compileLog(std.fmt.comptimePrint("{x}", .{UUID.Data1}));

            var callback: Callback(
                UUID,
                Context,
                Context.invoke,
            ) = .init(.{ .reset_event = &reset_event });

            try self.put_Completed(callback.handler());
            reset_event.wait();

            return switch (async_info.get_Status()) {
                .Started => unreachable,
                .Completed => self.GetResults(),
                .Error => error.UnhandledError, // todo: get error stuff from info
                .Canceled => error.Canceled,
            };
        }
    };
}
