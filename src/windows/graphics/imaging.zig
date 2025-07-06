const std = @import("std");
const windows = @import("../../windows.zig");
const winrt = @import("../winrt.zig");
const assert = std.debug.assert;

const GUID = windows.GUID;
const WINAPI = windows.WINAPI;
const HRESULT = windows.HRESULT;
const IUnknown = windows.IUnknown;
const IRandomAccessStream = windows.IRandomAccessStream;
const IAsyncOperation = winrt.IAsyncOperation;
const UINT32 = windows.UINT32;
const BitmapPixelFormat = windows.BitmapPixelFormat;
const BitmapAlphaMode = windows.BitmapAlphaMode;
const ExifOrientationMode = windows.ExifOrientationMode;
const ColorManagementMode = windows.ColorManagementMode;

pub const IBitmapTransform = opaque{};

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

    pub const GetFrameAsyncError = error{Unexpected};

    pub fn GetFrameAsync(self: *IBitmapDecoder, frameIndex: UINT32) GetFrameAsyncError!*IAsyncOperation(*IBitmapFrame) {
        const FnType = fn (*IBitmapDecoder, UINT32, **IAsyncOperation(*IBitmapFrame)) callconv(WINAPI) HRESULT;
        const get_frame_async: *const FnType = @ptrCast(self.vtable[10]);

        var operation: *IAsyncOperation(*IBitmapFrame) = undefined;

        const hr = get_frame_async(self, frameIndex, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IBitmapFrame = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Graphics.Imaging.BitmapFrame";
    pub const SIGNATURE = "rc(" ++ NAME ++ ";{72a49a1c-8081-438d-91bc-94ecfc8185c6})";

    pub inline fn Release(self: *IBitmapFrame) void {
        IUnknown.Release(@ptrCast(self));
    }

    pub fn get_PixelWidth(self: *IBitmapFrame) UINT32 {
        const FnType = fn (*IBitmapFrame, *UINT32) callconv(WINAPI) HRESULT;
        const get_pixel_width: *const FnType = @ptrCast(self.vtable[12]);

        var value: UINT32 = undefined;

        assert(get_pixel_width(self, &value) == windows.S_OK);
        return value;
    }

    pub fn get_PixelHeight(self: *IBitmapFrame) UINT32 {
        const FnType = fn (*IBitmapFrame, *UINT32) callconv(WINAPI) HRESULT;
        const get_pixel_height: *const FnType = @ptrCast(self.vtable[13]);

        var value: UINT32 = undefined;

        assert(get_pixel_height(self, &value) == windows.S_OK);
        return value;
    }

    pub const GetPixelDataAsyncError = error{Unexpected};

    pub fn GetPixelDataTransformedAsync(
        self: *IBitmapFrame,
        pixelFormat: BitmapPixelFormat,
        alphaMode: BitmapAlphaMode,
        transform: ?*IBitmapTransform,
        exifOrientationMode: ExifOrientationMode,
        colorManagementMode: ColorManagementMode,
    ) GetPixelDataAsyncError!*IAsyncOperation(*IPixelDataProvider) {
        const FnType = fn (
            *IBitmapFrame,
            BitmapPixelFormat,
            BitmapAlphaMode,
            ?*IBitmapTransform,
            ExifOrientationMode,
            ColorManagementMode,
            **IAsyncOperation(*IPixelDataProvider),
        ) callconv(WINAPI) HRESULT;

        const get_pixel_data_transformed_async: *const FnType = @ptrCast(self.vtable[17]);
        var operation: *IAsyncOperation(*IPixelDataProvider) = undefined;

        const hr = get_pixel_data_transformed_async(self, pixelFormat, alphaMode, transform, exifOrientationMode, colorManagementMode, &operation);
        return switch (hr) {
            windows.S_OK => operation,
            else => windows.unexpectedError(windows.HRESULT_CODE(hr)),
        };
    }
};

pub const IPixelDataProvider = extern struct {
    vtable: [*]const *const anyopaque,

    pub const NAME = "Windows.Graphics.Imaging.PixelDataProvider";
    pub const SIGNATURE = "rc(" ++ NAME ++ ";{dd831f25-185c-4595-9fb9-ccbe6ec18a6f})";

    pub inline fn Release(self: *IPixelDataProvider) void {
        IUnknown.Release(@ptrCast(self));
    }
};
