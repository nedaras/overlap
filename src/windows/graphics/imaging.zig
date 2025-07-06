const windows = @import("../../windows.zig");
const winrt = @import("../winrt.zig");

const GUID = windows.GUID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const IUnknown = windows.IUnknown;
const IRandomAccessStream = windows.IRandomAccessStream;
const IAsyncOperation = winrt.IAsyncOperation;

pub const IBitmapDecoderStatics = extern struct {
    vtable: [*]const *const anyopaque,
    
    pub const UUID = &GUID.parse("{438ccb26-bcef-4e95-bad6-23a822e58d01}");

    pub inline fn Release(self: *IBitmapDecoderStatics) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub const CreateAsyncError = error{Unexpected};

    pub fn CreateAsync(self: *IBitmapDecoderStatics, stream: *IRandomAccessStream) CreateAsyncError!*IAsyncOperation(*IBitmapDecoder) {
        const FnType = fn (*IBitmapDecoderStatics, *IRandomAccessStream, **IAsyncOperation(*IBitmapDecoder)) callconv(WINAPI) HRESULT;
        const create_async: *const FnType = @ptrCast(self.vtable[14]);

        var operation: *IAsyncOperation(*IBitmapDecoder) = undefined;

        const hr = create_async(self, stream, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }

};

pub const IBitmapDecoder = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Graphics.Imaging.BitmapDecoder";
    pub const SIGNATURE = "rc(" ++ NAME ++ ";{acef22ba-1d74-4c91-9dfc-9620745233e6})";

    pub inline fn Release(self: *IBitmapDecoder) void {
        IUnknown.Release(@ptrCast(self));
    }
};
