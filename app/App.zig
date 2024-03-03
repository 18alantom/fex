const std = @import("std");
const tree = @import("./tree.zig");
const Manager = @import("../fs/Manager.zig");
const tui = @import("../tui.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const print = std.debug.print;
const bS = tui.style.bufStyle;

rows: usize = 10,
allocator: mem.Allocator,
manager: *Manager,

const State = {};

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    return .{
        .allocator = allocator,
        .manager = try Manager.init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.manager.deinit();
}

const Entry = Manager.Iterator.Entry;
pub fn run(self: *Self) !void {
    _ = try self.manager.root.children();

    // Buffer iterated elements to allow backtracking
    var view_buffer = std.ArrayList(Entry).init(self.allocator);
    defer view_buffer.deinit();

    // Tree View to format output
    var tv = tree.TreeView.init(self.allocator);
    defer tv.deinit();

    // Stdout writer and buffer
    const writer = io.getStdOut().writer();
    var obuf: [2048]u8 = undefined; // content buffer
    var sbuf: [2048]u8 = undefined; // style buffer
    var out = tui.Draw{ .writer = writer };

    // Stdin reader and buffer
    const reader = io.getStdIn().reader();
    var rbuf: [2048]u8 = undefined;
    var inp = tui.Input{ .reader = reader };

    // Cursor and view boundaries
    var cursor: usize = 0;
    var vb_first: usize = 0; // First Index
    var vb_last: usize = 0; // Last Index

    var reiterate = false;
    var iter = try self.manager.iterate(-2);
    defer iter.deinit();

    // Pre-fill iter buffer
    for (0..self.rows) |i| {
        const _e = iter.next();
        if (_e == null) {
            break;
        }

        const e = _e.?;
        try view_buffer.append(e);
        vb_last = i;
    }

    try tui.terminal.enableRawMode();
    defer tui.terminal.disableRawMode() catch {};

    while (true) {
        // If manager tree changes in any way
        if (reiterate) {
            view_buffer.clearAndFree();
            iter.deinit();
            iter = try self.manager.iterate(-2);
        }

        // Cursor exceeds bottom boundary
        if (cursor > vb_last) {
            // View buffer in range, no need to append
            if (vb_last < (view_buffer.items.len - 1)) {
                vb_first += 1;
                vb_last += 1;
            }

            // View buffer out of range, need to append
            else if (iter.next()) |e| {
                try view_buffer.append(e);
                vb_first += 1;
                vb_last += 1;
            }

            // No more items, reset cursor
            else {
                cursor = vb_last;
            }
        }

        // Cursor exceeds top boundary
        else if (cursor < vb_first) {
            vb_first -= 1;
            vb_last -= 1;
        }

        // Print contents of view buffer in range
        for (vb_first..(vb_last + 1)) |i| {
            const e = view_buffer.items[i];

            var cursor_style: []u8 = undefined;
            if (cursor == i) {
                cursor_style = try bS(&sbuf, .{ .fg = tui.style.Color.magenta });
            } else {
                cursor_style = try bS(&sbuf, .{ .fg = tui.style.Color.default });
            }

            var line = try tv.line(e, &obuf);
            try out.println(line, cursor_style);
        }

        // Wait for input
        while (true) {
            const action = try inp.readAction(&rbuf);
            switch (action) {
                .quit => return,
                .down => cursor += 1,
                .up => cursor -|= 1,
                // Implement others
                .unknown => continue,
                else => continue,
            }

            break;
        }
    }
}

test "test" {}
