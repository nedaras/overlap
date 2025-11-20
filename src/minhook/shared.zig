const std = @import("std");

const Mutex = std.Thread.Mutex;

var m: Mutex = .{};
