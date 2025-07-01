const windows = @import("../windows.zig");

const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;

pub fn IAsyncOperation(comptime T: type) type {
    return extern struct {
        vtable: [*]const *const anyopaque,

        const Self = @This();

        pub const GetResultError = error{Unexpected};

        pub fn GetResult(self: *Self) GetResultError!T {
            const FnType = fn (*Self, *T) callconv(WINAPI) HRESULT;
            const get_result: *const FnType = @ptrCast(self.vtable[8]);

            var val: T = undefined;

            const hr = get_result(self, &val);
            return switch (hr) {
                windows.S_OK => val,
                else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
            };
        }
    };
}
