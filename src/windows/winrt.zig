const windows = @import("../windows.zig");

const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;

pub fn IAsyncOperation(comptime T: type) type {
    return extern struct {
        vtable: [*]const *const anyopaque,

        const Self = @This();

        pub const StatusError = error{Unexpected};

        pub fn Status(self: *Self) StatusError!windows.INT {
            const FnType = fn (*Self, *windows.INT) callconv(WINAPI) HRESULT;
            const get_status: *const FnType = @ptrCast(self.vtable[7]);

            var val: windows.INT = undefined;
            const hr = get_status(self, &val);
            return switch (hr) {
                windows.S_OK => val,
                else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
            };
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
