const windows = @import("../../windows.zig");

const GUID = windows.GUID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const IAsyncOperation = windows.IAsyncOperation;

pub const GlobalSystemMediaTransportControlsSessionManager = *IGlobalSystemMediaTransportControlsSessionManager;

pub const IGlobalSystemMediaTransportControlsSessionManager = extern struct {
    vtable: [*]const *const anyopaque,
};

pub const IGlobalSystemMediaTransportControlsSessionManagerStatics = extern struct {
    vtable: [*]const *const anyopaque,

    /// __uuidof(IGlobalSystemMediaTransportControlsSessionManagerStatics) = `"2050c4ee-11a0-57de-aed7-c97c70338245"`
    pub const UUID = &GUID{
        .Data1 = 0x2050c4ee,
        .Data2 = 0x11a0,
        .Data3 = 0x57de,
        .Data4 = .{
            0xae, 0xd7,
            0xc9, 0x7c,
            0x70, 0x33,
            0x82, 0x45,
        },
    };

    pub const RequestAsyncError = error{Unexpected};

    pub fn RequestAsync(
        self: *IGlobalSystemMediaTransportControlsSessionManagerStatics,
    ) RequestAsyncError!*IAsyncOperation(GlobalSystemMediaTransportControlsSessionManager) {
        const FnType = fn (*IGlobalSystemMediaTransportControlsSessionManagerStatics, **IAsyncOperation(GlobalSystemMediaTransportControlsSessionManager)) callconv(WINAPI) HRESULT;
        const request_async: *const FnType = @ptrCast(self.vtable[6]);

        var operation: *IAsyncOperation(GlobalSystemMediaTransportControlsSessionManager) = undefined;
        
        const hr = request_async(self, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};
