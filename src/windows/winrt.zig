const windows = @import("../windows.zig");

const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;

pub fn IAsyncOperation(comptime T: type) type {
    return extern struct {
        vtable: [*]const *const anyopaque,

        const Self = @This();

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
