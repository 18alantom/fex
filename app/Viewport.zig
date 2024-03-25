const std = @import("std");
const terminal = @import("../tui/terminal.zig");
const utils = @import("../utils.zig");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const os = std.os;

// pub const Viewport = struct {
// Terminal related fields
size: terminal.Size, // terminal dims
position: terminal.Position, // cursor position

// Display related fields
max_rows: u16 = 1, // max rows
start_row: u16 = 0,

const Self = @This();

pub fn init() !Self {
    try terminal.enableRawMode();
    return .{
        .max_rows = 0,
        .start_row = 0,
        .size = terminal.Size{ .cols = 0, .rows = 0 },
        .position = terminal.Position{ .col = 0, .row = 0 },
    };
}

pub fn deinit(_: *Self) void {
    terminal.disableRawMode() catch {};
}

pub fn setBounds(self: *Self) !void {
    self.size = terminal.getTerminalSize();
    self.position = try Self.getAdjustedPosition(self.size);
    self.max_rows = self.size.rows - self.position.row;
    self.start_row = Self.getStartRow(
        self.max_rows,
        self.position,
    );
}

fn getAdjustedPosition(size: terminal.Size) !terminal.Position {
    var position = try terminal.getCursorPosition();
    const min_rows = size.rows / 2;

    const rows_below = size.rows - position.row;
    if (rows_below > min_rows) {
        return position;
    }

    // Adjust Position: shift prompt (and cursor) up with newlines
    var obuf: [1024]u8 = undefined;
    var shift = min_rows - rows_below + 1;
    var newlines = utils.repeat(&obuf, "\n", shift);
    _ = try os.write(os.STDOUT_FILENO, newlines);

    return terminal.Position{
        .row = size.rows - shift,
        .col = position.col,
    };
}

fn getStartRow(rows: u16, pos: terminal.Position) u16 {
    if (pos.row > rows) {
        // unreachable after adjusted position
        return pos.row - rows;
    }

    return pos.row;
}
// };
