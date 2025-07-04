const windows = @import("../../windows.zig");

const INT64 = i64;
const GUID = windows.GUID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const HSTRING = windows.HSTRING;
const IUnknown = windows.IUnknown;
const IAsyncOperation = windows.IAsyncOperation;
const TypedEventHandler = windows.TypedEventHandler;

pub const EventRegistrationToken = extern struct {
    value: INT64,
};

pub const IMediaPropertiesChangedEventArgs = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Media.Control.MediaPropertiesChangedEventArgs";
    pub const SIGNATURE = "rc(" ++ NAME ++ ";{7d3741cb-adf0-5cef-91ba-cfabcdd77678})";
};

pub const IGlobalSystemMediaTransportControlsSessionMediaProperties = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties";

    pub const SIGNATURE = "rc(" ++ NAME ++ ";{68856cf6-adb4-54b2-ac16-05837907acb6})";

    pub const UUID = &GUID.parse("{68856cf6-adb4-54b2-ac16-05837907acb6}");

    pub inline fn Release(self: *IGlobalSystemMediaTransportControlsSessionMediaProperties) void {
        IUnknown.Release(@ptrCast(self));
    }

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

    pub const GetArtistError = error{Unexpected};

    pub fn get_Artist(self: *IGlobalSystemMediaTransportControlsSessionMediaProperties) GetArtistError!HSTRING {
        const FnType = fn (self: *IGlobalSystemMediaTransportControlsSessionMediaProperties, *HSTRING) callconv(WINAPI) HRESULT;
        const get_artist: *const FnType = @ptrCast(self.vtable[9]);

        var value: HSTRING = undefined;

        const hr = get_artist(self, &value);
        return switch (hr) {
            windows.S_OK => value,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IGlobalSystemMediaTransportControlsSession = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Media.Control.GlobalSystemMediaTransportControlsSession";
    pub const SIGNATURE = "rc(" ++ NAME ++ ";{7148c835-9b14-5ae2-ab85-dc9b1c14e1a8})";

    pub const TryGetMediaPropertiesAsyncError = error{Unexpected};

    pub inline fn Release(self: *IGlobalSystemMediaTransportControlsSession) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub fn TryGetMediaPropertiesAsync(
        self: *IGlobalSystemMediaTransportControlsSession,
    ) TryGetMediaPropertiesAsyncError!*IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionMediaProperties) {
        const FnType = fn (*IGlobalSystemMediaTransportControlsSession, **IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionMediaProperties)) callconv(WINAPI) HRESULT;
        const try_get_media_properties_async: *const FnType = @ptrCast(self.vtable[7]);

        var operation: *IAsyncOperation(*IGlobalSystemMediaTransportControlsSessionMediaProperties) = undefined;

        const hr = try_get_media_properties_async(self, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

    pub const AddMediaPropertiesChangedError = error{Unexpected};

    pub fn add_MediaPropertiesChanged(
        self: *IGlobalSystemMediaTransportControlsSession,
        handler: *TypedEventHandler(*IGlobalSystemMediaTransportControlsSession, *IMediaPropertiesChangedEventArgs),
    ) AddMediaPropertiesChangedError!EventRegistrationToken {
        const FnType = fn (
            *IGlobalSystemMediaTransportControlsSession,
            *TypedEventHandler(*IGlobalSystemMediaTransportControlsSession, *IMediaPropertiesChangedEventArgs),
            *EventRegistrationToken
        ) callconv(WINAPI) HRESULT;

        const add_media_proparties_changed: *const FnType = @ptrCast(self.vtable[29]);

        var token: EventRegistrationToken = undefined;

        const hr = add_media_proparties_changed(self, handler, &token);
        return switch (hr) {
            windows.S_OK => token,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

};

// prob add those GlobalSystemMediaTransportControlsSessionManager classes for general use
pub const IGlobalSystemMediaTransportControlsSessionManager = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager";

    pub const SIGNATURE = "rc(" ++ NAME ++ ";{cace8eac-e86e-504a-ab31-5ff8ff1bce49})";

    pub const UUID = &GUID.parse("{cace8eac-e86e-504a-ab31-5ff8ff1bce49}");

    pub const GetCurrentSessionError = error{Unexpected};

    pub inline fn Release(self: *IGlobalSystemMediaTransportControlsSessionManager) void {
        IUnknown.Release(@ptrCast(self));
    }

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

    pub const NAME = "Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager";
    pub const SIGNATURE = "rc(" ++ NAME ++ ";{2050c4ee-11a0-57de-aed7-c97c70338245})";

    pub const UUID = &GUID.parse("{2050c4ee-11a0-57de-aed7-c97c70338245}");

    pub const RequestAsyncError = error{Unexpected};

    pub inline fn Release(self: *IGlobalSystemMediaTransportControlsSessionManagerStatics) void {
        IUnknown.Release(@ptrCast(self));
    }

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
