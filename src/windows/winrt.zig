const std = @import("std");
const windows = @import("../windows.zig");
const assert = std.debug.assert;

const INT = windows.INT;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;

pub const AsyncStatus = enum(INT) {
    Started = 0,
    Completed = 1,
    Canceled = 2,
    Error = 3,
};

pub fn IAsyncOperation(comptime T: type) type {
    return extern struct {
        vtable: [*]const *const anyopaque,

        const Self = @This();

        // todo: make these funcs private and wrap them up as many stuff can happen here

        pub fn get_Status(self: *Self) AsyncStatus {
            const FnType = fn (*Self, *AsyncStatus) callconv(WINAPI) HRESULT;
            const get_status: *const FnType = @ptrCast(self.vtable[7]);

            var val: AsyncStatus = undefined;
            assert(get_status(self, &val) == windows.S_OK);

            return val;
        }

        pub const GetResultsError = error{Unexpected};

        pub fn GetResults(self: *Self) GetResultsError!T {
            const FnType = fn (*Self, *T) callconv(WINAPI) HRESULT;
            const get_results: *const FnType = @ptrCast(self.vtable[13]);

            var val: T = undefined;

            const hr = get_results(self, &val);
            return switch (hr) {
                windows.S_OK => val,
                else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
            };
        }
    };
}
