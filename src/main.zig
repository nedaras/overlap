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

    try action.post(.{ &spotify, SendOptions{ .cmd = .curr }});

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

    var latest_timestamp_ms: ?i64 = null;
    var track_ends_ms: ?i64 = null;

    while (true) {
        try hook.newFrame();
        defer hook.endFrame();

        defer prev_mouse_ldown = input.mouse_ldown;

        if (action.dispatch()) |x| {
            const track: std.json.Parsed(Spotify.Track), const stb_image: stb.Image = try x;
            defer track.deinit();
            defer stb_image.deinit();

            latest_timestamp_ms = track.value.timestamp;
            track_ends_ms = track.value.timestamp + track.value.item.duration_ms;

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
                try action.post(.{ &spotify, SendOptions{ 
                    .cmd = .next,
                    .timestamp = latest_timestamp_ms,
                }});
            } else if (track_ends_ms != null and std.time.milliTimestamp() >= track_ends_ms.?) {
                track_ends_ms = null;
                try action.post(.{ &spotify, SendOptions{
                    .cmd = .curr,
                    .timestamp = latest_timestamp_ms,
                }});
            }

            gui.text(.{ @floatFromInt(input.mouse_x), @floatFromInt(input.mouse_y) }, "Helo", 0xFFFFFFFF, font);
        }
    }
}

const SendOptions = struct {
    cmd: Command,
    timestamp: ?i64 = null,
};

// curr problems...
// after skipping from other device it f ups our timestamp state and again we're out of sync
//     guess we could like get curr track before skip and then after skip, seems most simple way to handle this out of sync shit
// crossfade as for now it can be set to 12 seconds soooo perhaps an idea is too idk make new req 12 seconds earlier and then
//     do it every second we detect a change and by doing this we can actually get users crossfade and cache for overlays lifespan (wow)
//     though this can bring us some problems as now sendCommand can take 12+ seconds
//     we would need a way to cancel curr action so we could post another (maybe by having a fallback thread)
// no actions are taken if spotify api returns errors we just panic by boubling errors
fn sendCommand(spotify: *Spotify, opts: SendOptions) !struct { std.json.Parsed(Spotify.Track), stb.Image } {
    const allocator = spotify.http_client.allocator;

    // todo: prefetch track before skip actions
    // and fetch new track till timestamps changes
    switch (opts.cmd) {
        .curr => {},
        .next => try spotify.skipToNext(),
        .previous => try spotify.skipToPrevious(),
    }

    const track = init: {
        if (opts.timestamp) |timestamp| {
            var delay_idx: u8 = 0;
            const delays = &[_]u8{ 0, 30, 30, 50, 50, 70, 70, 100 };

            while (true) {
                const delay: u64 = @intCast(delays[delay_idx]);
                defer delay_idx = @min(delay_idx + 1, delays.len);

                std.Thread.sleep(std.time.ns_per_ms * delay);

                const tmp_track = try spotify.getCurrentlyPlayingTrack();
                if (tmp_track.value.timestamp != timestamp) {
                    break: init tmp_track;
                }
                tmp_track.deinit();
            }
        }

        break :init try spotify.getCurrentlyPlayingTrack();
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
