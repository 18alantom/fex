const std = @import("std");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const os = std.os;

const Manager = @import("../fs/Manager.zig");
const Entry = Manager.Iterator.Entry;

const Self = @This();

allocator: mem.Allocator,
buffer: std.ArrayList(Entry),

first: usize, // first index (top buffer boundary)
last: usize, // last index (bottom buffer boundar)
cursor: usize, // location in buffer boundary

pub fn init(allocator: mem.Allocator) Self {
    return .{
        .allocator = allocator,
        .buffer = std.ArrayList(Entry).init(allocator),
        .cursor = 0,
        .first = 0,
        .last = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.buffer.deinit();
}

pub fn update(
    self: *Self,
    iter: *Manager.Iterator,
    max_rows: u16,
) !void {
    if (self.first == 0) self.fixLast(max_rows);
    while (true) {
        // Cursor exceeds bottom boundary
        if (self.cursor > self.last) {
            try self.incrementIndices(iter);
        }

        // Cursor exceeds top boundary
        else if (self.cursor < self.first) {
            self.decrementIndices();
        }

        // Break
        else {
            break;
        }
    }
    self.fixLast(max_rows);
}

fn fixLast(self: *Self, max_rows: u16) void {
    const max_diff = self.first + max_rows;
    const buffer_len = self.buffer.items.len;
    self.last = @min(max_diff, buffer_len) - 1;
}

fn incrementIndices(self: *Self, _iter: *Manager.Iterator) !void {
    var iter = _iter; // _iter is const

    // Self buffer in range, no need to append
    if (self.last < (self.buffer.items.len - 1)) {
        self.first += 1;
        self.last += 1;
    }

    // Self buffer out of range, need to append
    else if (iter.next()) |e| {
        try self.buffer.append(e);
        self.first += 1;
        self.last += 1;
    }

    // No more items, reset cursor
    else {
        self.cursor = self.last;
    }
}

fn decrementIndices(self: *Self) void {
    const diff = self.last - self.first;
    self.first = self.cursor;
    self.last = self.first + diff;
}
