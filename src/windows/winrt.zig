const std = @import("std");
const windows = @import("../windows.zig");
const assert = std.debug.assert;

const INT = windows.INT;
const REFIID = windows.REFIID;
const GUID = windows.GUID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const IUnknown = windows.IUnknown;

pub const AsyncStatus = enum(INT) {
    Started = 0,
    Completed = 1,
    Canceled = 2,
    Error = 3,
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
