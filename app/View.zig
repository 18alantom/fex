/// View is responsible for maintaing View.buffer which is an
/// ArrayList of fs items to be displayed.
///
/// It maintains the cursor, and first and last incices to keep
/// track of what portion of the buffer is in view.
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

did_scroll: bool, // Whether cursor exceded bounds
did_diff_change: bool, // last - first changed
prev_cursor: usize, // Previous cursor position.

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
        .prev_cursor = 0,
        .did_scroll = false,
        .did_diff_change = false,
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
    const initial_diff = self.last - self.first;
    if (self.first == 0) {
        self.correct(max_rows);
    }

    self.did_scroll = self.cursor > self.last or self.cursor < self.first;
    while (true) {
        // Cursor exceeds bottom boundary
        if (self.cursor > self.last) {
            try self.incrementIndices(iter);
        }

        // Cursor exceeds top boundary
        else if (self.cursor < self.first) {
            self.decrementIndices();
        }

        // Break, cursor within bounds
        else {
            break;
        }
    }
    self.correct(max_rows);
    self.did_diff_change = (self.last - self.first) != initial_diff;
}

fn correct(self: *Self, max_rows: u16) void {
    const current_diff: usize = self.last -| self.first;
    const max_diff: usize = self.first + max_rows;

    // Correct `last`: ensure `last` less than buffer len
    self.last = @min(max_diff, self.buffer.items.len) - 1;
    if (self.first == 0) {
        return;
    }

    // Correct `first`: ensure `first` before `last`
    if (current_diff > 0) {
        self.first = self.last -| current_diff;
    }

    // no-op after update loop
    // Correct `cursor`: place `cursor` within bounds
    if (self.cursor < self.first) {
        self.cursor = self.first;
    } else if (self.cursor > self.last) {
        self.cursor = self.last;
    }
}

fn incrementIndices(self: *Self, iter: *Manager.Iterator) !void {
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
