const std = @import("std");
const math = std.math;

extern fn stbi_load_from_memory(
    buffer: [*]const u8,
    len: c_int,
    x: *c_int,
    y: *c_int,
    channels_in_file: *c_int,
    desired_channels: c_int,
) callconv(.C) ?[*]u8;

extern fn stbi_image_free(retval_from_stbi_load: [*]u8) callconv(.C) void;

extern fn stbi_failure_reason() callconv(.C) [*:0]const u8;

pub const StbImage = struct {
    data: []u8,
    width: u32,
    height: u32,
    channels: Channel,

    pub fn deinit(self: StbImage) void {
        stbi_image_free(self.data.ptr);
    }
};

pub const Channel = enum(c_int) {
    r = 1,
    rg = 2,
    rgb = 3,
    rgba = 4,
};

pub const ImageOptions = struct {
    channels: ?Channel = null,
};

pub const LoadImageFromMemoryError = error{
    ImageTooBig,
    Unexpected,
};

pub fn loadImageFromMemory(bytes: []const u8, options: ImageOptions) LoadImageFromMemoryError!StbImage {
    if (bytes.len > std.math.maxInt(c_int)) {
        return error.ImageTooBig;
    }

    var width: c_int = undefined;
    var height: c_int = undefined;
    var channels: c_int = undefined;

    const desired_channels = if (options.channels) |chan| @intFromEnum(chan) else 0;

    if (stbi_load_from_memory(bytes.ptr, @intCast(bytes.len), &width, &height, &channels, desired_channels)) |data| {
        const len: usize = @intCast(width * height * (if (desired_channels == 0) channels else desired_channels));

        return .{
            .data = data[0..len],
            .width = @intCast(width),
            .height = @intCast(height),
            .channels = options.channels orelse @enumFromInt(channels),
        };
    }

    if (std.posix.unexpected_error_tracing) {
        std.debug.print("error.Unexpected: stbi_failure: {s}\n", .{stbi_failure_reason()});
    }

    return error.Unexpected;
}
