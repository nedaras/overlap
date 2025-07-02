const windows = @import("../../windows.zig");

const GUID = windows.GUID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const HSTRING = windows.HSTRING;
const IAsyncOperation = windows.IAsyncOperation;

pub const IGlobalSystemMediaTransportControlsSessionMediaProperties = extern struct {
    vtable: [*]const *const anyopaque,

    pub const GetTitleError = error{Unexpected};

    pub fn get_Title(self: *IGlobalSystemMediaTransportControlsSessionMediaProperties) GetTitleError!HSTRING {
        const FnType = fn (self: *IGlobalSystemMediaTransportControlsSessionMediaProperties, *HSTRING) callconv(WINAPI) HRESULT;
        const get_title: *const FnType = @ptrCast(self.vtable[6]);

        var value: HSTRING = undefined;

        const hr = get_title(self, &value);
        return switch (hr) {
            windows.S_OK => value,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

};

pub const IGlobalSystemMediaTransportControlsSession = extern struct {
    vtable: [*]const *const anyopaque,

    pub const TryGetMediaPropertiesAsyncError = error{Unexpected};

    pub fn TryGetMediaPropertiesAsync(
        self: *IGlobalSystemMediaTransportControlsSession,
    ) TryGetMediaPropertiesAsyncError!*IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionMediaProperties) {
        const FnType = fn (*IGlobalSystemMediaTransportControlsSession, **IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionMediaProperties)) callconv(WINAPI) HRESULT;
        const request_async: *const FnType = @ptrCast(self.vtable[7]);

        var operation: *IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionMediaProperties) = undefined;
        
        const hr = request_async(self, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

};

pub const IGlobalSystemMediaTransportControlsSessionManager = extern struct {
    vtable: [*]const *const anyopaque,

    pub const GetCurrentSessionError = error{Unexpected};

    pub fn GetCurrentSession(self: *IGlobalSystemMediaTransportControlsSessionManager) GetCurrentSessionError!?*IGlobalSystemMediaTransportControlsSession {
        const FnType = fn (*IGlobalSystemMediaTransportControlsSessionManager, *?*IGlobalSystemMediaTransportControlsSession) callconv(WINAPI) HRESULT;
        const get_current_session: *const FnType = @ptrCast(self.vtable[6]);

        var val: ?*IGlobalSystemMediaTransportControlsSession = undefined;

        const hr = get_current_session(self, &val);
        return switch (hr) {
            windows.S_OK => val,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

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
    ) RequestAsyncError!*IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionManager) {
        const FnType = fn (*IGlobalSystemMediaTransportControlsSessionManagerStatics, **IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionManager)) callconv(WINAPI) HRESULT;
        const request_async: *const FnType = @ptrCast(self.vtable[6]);

        var operation: *IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionManager) = undefined;
        
        const hr = request_async(self, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};
