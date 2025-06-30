const std = @import("std");
const stb = @import("stb.zig");
const actions = @import("actions.zig");
const Client = @import("http.zig").Client;
const Spotify = @import("Spotify.zig");
const Hook = @import("Hook.zig");
const time = std.time;
const Uri = std.Uri;
const assert = std.debug.assert;

const max_crossover_ms = 12_000;

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

    var action: actions.SingleAction(SendCommandResponse) = undefined;

    try action.init(allocator);
    defer action.deinit();

    try action.post(sendCommand, .{ &spotify, SendCommandOptions{ .cmd = .curr } });
    // still can leak say that work is only completed if deinit of acion is called
    // mb add like cleanup func in init so in deinit after joins if worker finished its job we can just clean it up
    defer if (action.dispatch()) |val| blk: {
        const track, const image = val catch break :blk;
        track.deinit();
        image.deinit();
    };

    var hook: Hook = .init;

    try hook.attach();
    defer hook.detach();

    const gui = hook.gui();
    //const input = hook.input();

    const font = try hook.loadFont(allocator, "font.fat");
    defer font.deinit(allocator);

    var cover: ?Hook.Image = null;
    defer if (cover) |cov| {
        cov.deinit(allocator);
        cover = null;
    };

    var track_ends_ms: ?i64 = null;
    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        if (action.dispatch()) |val| {
            const track, const image = try val;
            defer track.deinit();
            defer image.deinit();

            // todo: handle them fucking crossfades
            // now our cover updates are delayed by crossfade and it even f with skip state
            // perhaps an idea is like detect minimum track_left_ms and assume it our crossfade???
            // track_left_ms seems best option, but how todo this nicely and with least error

            const timestamp_ms = time.milliTimestamp();
            const track_left_ms = track.value.item.duration_ms - track.value.progress_ms;

            defer track_ends_ms = timestamp_ms + track_left_ms;

            if (cover == null or cover.?.width != image.width or cover.?.height != image.height) {
                @branchHint(.cold);

                if (cover) |cov| {
                    cov.deinit(allocator);
                    cover = null;
                }

                cover = try hook.loadImage(allocator, .{
                    .data = image.data,
                    .width = image.width,
                    .height = image.height,
                    .format = .rgba,
                    .usage = .dynamic,
                });
            } else {
                try hook.updateImage(cover.?, image.data);
            }
        }

        if (track_ends_ms) |timestamp| {
            if (time.milliTimestamp() >= timestamp) {
                try action.post(sendCommand, .{ &spotify, SendCommandOptions{ .cmd = .curr } });
                track_ends_ms = null;
            }
        }

        if (cover) |cov| {
            gui.image(.{ 0.0, 0.0 }, .{ @floatFromInt(cov.width), @floatFromInt(cov.height) }, cov);
        }
    }
}

const Command = enum {
    curr,
    next,
    previous,
};

const SendCommandOptions = struct {
    cmd: Command,
};

const SendCommandError = Spotify.GetCurrentlyPlayingTrackError || Uri.ParseError || stb.LoadImageFromMemoryError || error{
    EndOfStream,
};

const SendCommandResponse = SendCommandError!struct {
    std.json.Parsed(Spotify.Track),
    stb.Image,
};

fn sendCommand(spotify: *Spotify, opts: SendCommandOptions) SendCommandResponse {
    const allocator = spotify.http_client.allocator;

    const timestamp = switch (opts.cmd) {
        .curr => null,
        .next, .previous => blk: {
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
            var delay_idx: u8 = 0;
            const delays = &[_]u16{ 0, 30, 50, 70, 100, 1000 };

            while (true) {
                const delay: u64 = @intCast(delays[delay_idx]);
                defer delay_idx = @min(delay_idx + 1, delays.len);

                std.Thread.sleep(std.time.ns_per_ms * delay);

                const tmp_track = try spotify.getCurrentlyPlayingTrack();
                if (tmp_track.value.timestamp != prev_timestamp) {
                    break :blk tmp_track;
                }
                tmp_track.deinit();
            }
        }
        break :blk try spotify.getCurrentlyPlayingTrack();
    };
    errdefer track.deinit();

    const uri = try Uri.parse(track.value.item.album.images[0].url);

    var server_header: [256]u8 = undefined;

    var req = try spotify.http_client.open(.GET, uri, .{
        .server_header_buffer = &server_header,
    });
    defer req.deinit();

    try req.send();
    req.finish() catch unreachable;

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
