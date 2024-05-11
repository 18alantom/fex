const std = @import("std");
const utils = @import("../utils.zig");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const os = std.os;

const CharArray = utils.CharArray;

is_capturing: bool,
buffer: *CharArray,
allocator: mem.Allocator,

const Self = @This();
pub fn init(allocator: mem.Allocator) !Self {
    const buffer = try allocator.create(CharArray);
    buffer.* = CharArray.init(allocator);
    return .{
        .buffer = buffer,
        .allocator = allocator,
        .is_capturing = false,
    };
}

pub fn deinit(self: *Self) void {
    self.buffer.deinit();
    self.allocator.destroy(self.buffer);
}

pub fn start(self: *Self) void {
    self.is_capturing = true;
}

pub fn stop(self: *Self, clear: bool) void {
    if (clear) self.buffer.clearAndFree();
    self.is_capturing = false;
}

pub fn capture(self: *Self, str: []const u8) !void {
    // 127 is Backspace
    if (str.len == 1 and str[0] == 127) {
        const new_len = self.buffer.items.len -| 1;
        self.buffer.shrinkRetainingCapacity(new_len);
        return;
    }

    _ = try self.buffer.appendSlice(str);
}

pub fn string(self: *Self) []const u8 {
    return self.buffer.items;
}
