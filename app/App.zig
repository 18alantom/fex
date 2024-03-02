const std = @import("std");
const tree = @import("./tree.zig");
const Manager = @import("../fs/Manager.zig");
const tui = @import("../tui.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const print = std.debug.print;

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

    // Stdout writer, and buffer
    const writer = io.getStdOut().writer();
    var obuf: [2048]u8 = undefined; // content buffer
    var sbuf: [2045]u8 = undefined; // style buffer
    var d = tui.Draw{ .writer = writer };

    var cursor: usize = 0;
    var vb_first: usize = 0; // First Index
    var vb_last: usize = 0; // Last Index
    var li: usize = 0; // Failsafe

    var reiterate = false;
    var iter = try self.manager.iterate(-2);

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

    while (true) {
        // If manager tree changes in any way
        if (reiterate) {
            view_buffer.clearAndFree();
            iter.stack.deinit();
            iter = try self.manager.iterate(-2);
        }

        // Reset cursor
        if (cursor < 0) {
            cursor = 0;
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
                cursor_style = try tui.style.bufStyle(&sbuf, .{ .fg = tui.style.Color.magenta });
            } else {
                cursor_style = try tui.style.bufStyle(&sbuf, .{ .fg = tui.style.Color.default });
            }

            var line = try tv.line(e, &obuf);
            try d.println(line, cursor_style);
        }

        // Fail safe
        li += 1;
        if (li == 10) break;
    }
}

test "test" {}
