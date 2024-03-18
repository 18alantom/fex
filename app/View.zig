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

pub fn update(self: *Self, iter: *Manager.Iterator) !void {
    // TODO: can do without loop
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
    self.first -= 1;
    self.last -= 1;
}
