const std = @import("std");
const builtin = @import("builtin");
const windows = @import("windows.zig");
const unicode = std.unicode;

pub const Client = struct {

    pub fn open(self: Client) !void {
        _ = self;

        const internet = try windows.WinHttpOpen(
            unicode.wtf8ToWtf16LeStringLiteral("zig/" ++ builtin.zig_version_string ++ " (winhttp)"),
            windows.WINHTTP_ACCESS_TYPE_NO_PROXY,
            windows.WINHTTP_NO_PROXY_NAME,
            windows.WINHTTP_NO_PROXY_BYPASS,
            0,
        );

        defer windows.WinHttpCloseHandle(internet);

    }

    pub fn deinit(self: Client) void {
        _ = self;
    }
};
