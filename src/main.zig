const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const assert = std.debug.assert;

const Command = enum {
    curr,
    next,
    previous,
};

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{ .thread_safe = true }){};
    defer _ = da.deinit();

    const allocator = da.allocator();

    var client = try Client.init(allocator);
    defer client.deinit();

    var spotify = Spotify{
        .http_client = &client,
        .authorization = "Bearer ...",
    };

    var action: actions.SingleAction(sendCommand) = undefined;

    try action.init(allocator);
    defer action.deinit();

    try action.post(.{ &spotify, SendOptions{ .cmd = .curr } });
    // still can leak say that work is only completed if deinit of acion is called
    // mb add like cleanup func in init so in deinit after joins if worker finished its job we can just clean it up
    defer if (action.dispatch()) |x| blk: {
        const track: std.json.Parsed(Spotify.Track), const stb_image: stb.Image = x catch break :blk;
        track.deinit();
        stb_image.deinit();
    };

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();
    const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    var cover: ?Hook.Image = null;
    defer if (cover) |cov| {
        cov.deinit(allocator);
        cover = null;
    };

    var prev_mouse_ldown = false;

    var track_ends_ms: ?i64 = null;
    var poll_track_ms: ?i64 = null;

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        defer prev_mouse_ldown = input.mouse_ldown;

        if (action.dispatch()) |x| {
            const track: std.json.Parsed(Spotify.Track), const stb_image: stb.Image = try x;
            defer track.deinit();
            defer stb_image.deinit();

            // will be a big problem if in a middle of a song someone skipped i guess we would need to add a check to know that we're even in sync
            // before padding calculation
            const padding = blk: {
                if (track_ends_ms) |end_ms| {
                    break :blk @divFloor(end_ms - track.value.item.duration_ms, 1000) * 1000;
                }
                break :blk 12000; // max crossover is 12s
            };

            std.debug.print("crossover: {d}\n", .{padding});

            track_ends_ms = track.value.timestamp + track.value.item.duration_ms;
            poll_track_ms = track.value.timestamp + track.value.item.duration_ms - padding;

            if (cover == null or cover.?.width != stb_image.width or cover.?.height != stb_image.height) {
                @branchHint(.cold);

                if (cover) |cov| {
                    cov.deinit(allocator);
                    cover = null;
                }

                cover = try hook.loadImage(allocator, .{
                    .data = stb_image.data,
                    .width = stb_image.width,
                    .height = stb_image.height,
                    .format = .rgba,
                    .usage = .dynamic,
                });
            } else {
                try hook.updateImage(cover.?, stb_image.data);
            }
        }

        const cov = cover orelse continue;

        gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(cov.width), @floatFromInt(cov.height) }, cov);

        if (action.busy()) {
            //gui.rect(.{ 100.0, 100.0 }, .{ 500.0, 500.0 }, 0x0F191EFF);
            gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, "Sending...", 0xFFFFFFFF, font);
        } else {
            const click = !prev_mouse_ldown and input.mouse_ldown;
            const in_bounds = input.mouse_x <= cov.width and input.mouse_y <= cov.height;

            if (click and in_bounds) {
                try action.post(.{ &spotify, SendOptions{ .cmd = .next } });
            } else if (poll_track_ms != null and std.time.milliTimestamp() >= poll_track_ms.?) {
                poll_track_ms = null;
                try action.post(.{ &spotify, SendOptions{ .cmd = .curr } });
            }

            gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, "Helo", 0xFFFFFFFF, font);
        }
    }
}

const SendOptions = struct {
    cmd: Command,
};

// curr problems...
// no actions are taken if spotify api returns errors we just panic by boubling errors
fn sendCommand(spotify: *Spotify, opts: SendOptions) !struct { std.json.Parsed(Spotify.Track), stb.Image } {
    const allocator = spotify.http_client.allocator;

    const timestamp = switch (opts.cmd) {
        .curr => null,
        else => blk: {
            const tmp_track = try spotify.getCurrentlyPlayingTrack();
            defer tmp_track.deinit();

            break :blk tmp_track.value.timestamp;
        },
    };

    switch (opts.cmd) {
        .curr => {},
        .next => try spotify.skipToNext(),
        .previous => try spotify.skipToPrevious(),
    }

    const track = blk: {
        if (timestamp) |prev_timestamp| {
            while (true) {
                const tmp_track = try spotify.getCurrentlyPlayingTrack();
                if (tmp_track.value.timestamp != prev_timestamp) {
                    break :blk tmp_track;
                }

                std.debug.print("miss\n", .{});

                tmp_track.deinit();
                // tofo: harsh if we're skipping, add like nullable delay option
                std.Thread.sleep(std.time.ns_per_ms * 1000);
            }
        }
        break :blk try spotify.getCurrentlyPlayingTrack();
    };
    errdefer track.deinit();

    const uri = try std.Uri.parse(track.value.item.album.images[0].url);

    var server_header: [256]u8 = undefined;

    var req = try spotify.http_client.open(.GET, uri, .{
        .server_header_buffer = &server_header,
    });
    defer req.deinit();

    try req.send();
    try req.finish();

    try req.wait();

    const image = try allocator.alloc(u8, req.response.content_length.?);
    defer allocator.free(image);

    try req.reader().readNoEof(image);

    return .{
        track,
        try stb.loadImageFromMemory(image, .{
            .channels = .rgba,
        }),
    };
}
