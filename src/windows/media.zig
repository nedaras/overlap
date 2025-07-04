const std = @import("std");
const windows = @import("../windows.zig");
const controls = @import("media/controls.zig");
const unicode = std.unicode;

const AsyncOperation = windows.AsyncOperation;
const IGlobalSystemMediaTransportControlsSessionManager = controls.IGlobalSystemMediaTransportControlsSessionManager;
const IGlobalSystemMediaTransportControlsSessionManagerStatics = controls.IGlobalSystemMediaTransportControlsSessionManagerStatics;

pub const GlobalSystemMediaTransportControlsSessionManager = struct {
    handle: *IGlobalSystemMediaTransportControlsSessionManager, 

    pub const SIGNATURE = IGlobalSystemMediaTransportControlsSessionManager.SIGNATURE;
    pub const NAME = IGlobalSystemMediaTransportControlsSessionManager.NAME;

    pub fn RequestAsync() !AsyncOperation(GlobalSystemMediaTransportControlsSessionManager) {
        // tood: use const ref string
        const class = try windows.WindowsCreateString(unicode.wtf8ToWtf16LeStringLiteral(NAME));
        defer windows.WindowsDeleteString(class);

        var static_manager: *IGlobalSystemMediaTransportControlsSessionManagerStatics = undefined;

        try windows.RoGetActivationFactory(
            class,
            IGlobalSystemMediaTransportControlsSessionManagerStatics.UUID,
            @ptrCast(&static_manager),
        );
        defer static_manager.Release();

        return .{
            // safe as GlobalSystemMediaTransportControlsSessionManager is just *IGlobalSystemMediaTransportControlsSessionManager
            .handle = @ptrCast(try static_manager.RequestAsync()),
        };
    }
};
