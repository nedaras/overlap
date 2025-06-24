const std = @import("std");
const stb = @import("stb.zig");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const assert = std.debug.assert;

const CoverImage = struct {
    allocator: std.mem.Allocator,

    image: Hook.Image,
    spotify: *Spotify,

    fn init(allocator: std.mem.Allocator, hook: *Hook, spotify: *Spotify) !CoverImage {
        const stb_image = try pullImage(allocator, spotify);
        defer stb_image.deinit();

        return .{
            .allocator = allocator,
            .image = try hook.loadImage(allocator, .{
                .data = stb_image.data,
                .width = stb_image.width,
                .height = stb_image.height,
                .format = .rgba,
                .usage = .dynamic,
            }),
            .spotify = spotify,
        };
    }

    fn update(self: *CoverImage, hook: *Hook) !void {
        const stb_image = try pullImage(self.allocator, self.spotify);
        defer stb_image.deinit();

        hook.updateImage(self.image, stb_image.data);
    }

    fn pullImage(allocator: std.mem.Allocator, spotify: *Spotify) !stb.Image {
        const track = try spotify.getCurrentlyPlayingTrack();
        defer track.deinit();

        const uri = try std.Uri.parse(track.value.item.album.images[0].url);

        var buf: [512]u8 = undefined;
        var req = try spotify.http_client.open(.GET, uri, .{
            .server_header_buffer = &buf,
        });
        defer req.deinit();

        try req.send();
        try req.finish();

        try req.wait();

        const jpeg = try allocator.alloc(u8, req.response.content_length.?);
        defer allocator.free(jpeg);

        assert(try req.readAll(jpeg) == jpeg.len);

        return stb.loadImageFromMemory(jpeg, .{ .channels = .rgba });
    }

    fn deinit(self: CoverImage) void {
        self.image.deinit(self.allocator);
    }
};

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client = try Client.init(allocator);
    defer client.deinit();

    var spotify = Spotify{
        .http_client = &client,
        .authorization = "Bearer ...",
    };

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    var cover = try CoverImage.init(allocator, &hook, &spotify);
    defer cover.deinit();

    const gui = hook.gui();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    var i: u32 = 0;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        i +%= 1;

        if (i % 1000 == 0) {
            try cover.update(&hook);
        }

        gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(cover.image.width), @floatFromInt(cover.image.height) }, cover.image);

        gui.text(.{ 200.0, 200.0 }, "Helogjk", 0xFFFFFFFF, font);
    }
}
