const std = @import("std");
const Backend = @import("Backend.zig");
const Image = @import("Image.zig");
const heap = std.heap;
const math = std.math;

// tood: upgrade with 0.15.1

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

allocator: Allocator,

backend: Backend,
image: Image,

data: []u8,
size: u32,

nodes: std.DoublyLinkedList,
nodes_pool: heap.MemoryPoolExtra(Data, .{ .growable = true }),

const Atlas = @This();

const Data = struct {
    x: u32,
    y: u32,

    width: u32,
    node: std.DoublyLinkedList.Node,
};

const Region = struct {
    x: u32,
    y: u32,

    width: u32,
    height: u32,
};

// todo: we need to allow growing it

pub fn init(allocator: Allocator, backend: Backend, size: u32) !Atlas {
    const data = try allocator.alloc(u8, size * size);
    errdefer allocator.free(data);

    var self: Atlas = .{
        .allocator = allocator,
        .backend = backend,
        .image = try backend.loadImage(allocator, .{
            .width = size,
            .height = size,
            .data = data,
            .format = .r,
            .usage = .dynamic,
        }),
        .data = data,
        .size = size,
        .nodes = .{},
        .nodes_pool = .init(allocator),
    };
    errdefer self.deinit();

    try self.nodes_pool.preheat(64);
    try self.clear();

    return self;
}

pub fn deinit(self: *Atlas) void {
    self.image.deinit(self.allocator);
    self.allocator.free(self.data);
    self.nodes_pool.deinit();

    self.* = undefined;
}

pub fn clear(self: *Atlas) !void {
    @memset(self.data, 0);
    try self.backend.updateImage(self.image, self.data);

    _ = self.nodes_pool.reset(.retain_capacity);

    self.nodes.first = null;
    self.nodes.last = null;

    var data = self.nodes_pool.create() catch unreachable;
    data.* = .{
        .x = 0,
        .y = 0,

        .width = self.size,
        .node = .{},
    };

    self.nodes.prepend(&data.node);
}

pub fn fill(
    self: *Atlas,
    region: Region,
    data: []u8
) !void {
    assert(data.len == region.width * region.height);
    assert(self.image.width > region.x);
    assert(self.image.height > region.y);

    for (0..region.height) |y| {
        const src_i = y * region.width;
        const dst_i = (y + region.y) * self.size + region.x;

        @memcpy(self.data[dst_i..dst_i + region.width], data[src_i..src_i + region.width]);
    }

    try self.backend.updateImage(self.image, self.data);
}

pub fn reserve(
    self: *Atlas,
    width: u32,
    height: u32,
) !Region {
    var region: Region = .{ .x = 0, .y = 0, .width = width, .height = height };

    const best_node = blk: {
        var best_width: u32 = math.maxInt(u32);
        var best_height: u32 = math.maxInt(u32);

        var selected: ?*Data = null;

        var curr = self.nodes.first;
        while (curr) |node| {
            defer curr = node.next;

            const data: *Data = @fieldParentPtr("node", node);
            const y = self.baseline(data, width, height) orelse continue;

            if (y + height < best_height or (y + height == best_height and data.width < best_width)) {
                selected = data;
                best_width = data.width;
                best_height = y + height;

                region.x = data.x;
                region.y = y;
            }
        }

        break :blk selected orelse return error.NoSpaceLeft;
    };

    const new_node = try self.nodes_pool.create();
    new_node.* = .{
        .x = region.x,
        .y = region.y + region.height,
        .width = region.width,
        .node = .{},
    };

    self.nodes.insertBefore(&best_node.node, &new_node.node);

    var prev = new_node;
    var curr: ?*Data = best_node;

    // loop till we're inside
    while (curr) |node| {
        // inside
        if (prev.x + prev.width > node.x) {
            const move = prev.x + prev.width - node.x;

            node.x += move;
            node.width -|= move;

            if (node.width == 0) {
                curr = if (node.node.next) |c| @fieldParentPtr("node", c) else null;

                self.nodes.remove(&node.node);
                self.nodes_pool.destroy(node);

                continue;
            }

            prev = node;
            curr = if (node.node.next) |n| @fieldParentPtr("node", n) else null;

            continue;
        }
        break;
    }

    if (new_node.node.next) |nn| {
        self.merge(new_node, @fieldParentPtr("node", nn));
    }

    if (new_node.node.prev) |pp| {
        self.merge(@fieldParentPtr("node", pp), new_node);
    }

    return region;
}

fn merge(self: *Atlas, left: *Data, right: *Data) void {
    if (left.y == right.y) {
        @branchHint(.cold);

        left.width += right.width;

        self.nodes.remove(&right.node);
        self.nodes_pool.destroy(right);
    }
}

fn baseline(
    self: Atlas,
    node: *Data,
    width: u32,
    height: u32,
) ?u32 {
    if (node.x + width > self.size) {
        return null;
    }

    var y = node.y;
    var width_left = width;

    var curr: ?*std.DoublyLinkedList.Node = &node.node;
    while (width_left > 0) {
        defer curr = curr.?.next;
        const data: *Data = @fieldParentPtr("node", curr.?);
        if (data.y + height > self.size) {
            return null;
        }

        y = @max(y, data.y);
        width_left -|= data.width;
    }

    return y;
}

pub fn dump(self: Atlas, writer: anytype) !void {
    try writer.print(
        \\P{c}
        \\{d} {d}
        \\255
        \\
    , .{
        '5',
        self.size,
        self.size,
    });
    try writer.writeAll(self.data);
}
