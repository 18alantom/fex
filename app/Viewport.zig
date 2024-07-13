/// Viewport is responsible for setting the terminal bounds within
/// which to display the contents of app.
const std = @import("std");
const terminal = @import("../tui/terminal.zig");
const utils = @import("../utils.zig");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const posix = std.posix;

const log = std.log.scoped(.viewport);

// Terminal related fields
size: terminal.Size, // terminal dims

// Display related fields
max_rows: u16 = 1, // max rows
start_row: u16 = 1, // 1 based index
termios_bak: posix.termios,

const Self = @This();

pub fn init() !Self {
    var bak: posix.termios = undefined;
    try terminal.enableRawMode(&bak);
    return .{
        .max_rows = 1,
        .start_row = 1,
        .size = terminal.Size{ .cols = 1, .rows = 1 },
        .termios_bak = bak,
    };
}

pub fn deinit(self: *Self) void {
    terminal.disableRawMode(&self.termios_bak) catch {};
}

pub fn initBounds(self: *Self) !void {
    self.size = terminal.getTerminalSize();
    self.start_row = try Self.adjustAndGetInitialStartRow(
        self.size,
        try terminal.getCursorPosition(),
    );
    self.updateMaxRows();
}

fn adjustAndGetInitialStartRow(size: terminal.Size, position: terminal.Position) !u16 {
    const min_rows = @min(size.rows / 2, 24);

    // Available rows below the cursor
    // - first `- 1`  to adjust for 1 based index
    // - second `- 1` to prevent scroll by print on last line
    const rows_below = size.rows - (position.row - 1) - 1;
    if (rows_below >= min_rows) {
        return position.row;
    }

    // Adjust Position: shift prompt (and cursor) up with newlines
    const scroll_lines = min_rows - rows_below;
    const row = size.rows - min_rows;
    const col = position.col;

    try Self.scrollAndSetCursor(scroll_lines, row, col);
    return row;
}

pub fn updateBounds(self: *Self) !bool {
    const cursorUpdated = self.handleClear() catch false;
    const prev_rows = self.size.rows;
    const size = terminal.getTerminalSize();

    if (size.rows == prev_rows) {
        return cursorUpdated;
    }

    self.size = size;
    try self.updateStartRow(size.rows, prev_rows);
    self.updateMaxRows();
    return true;
}

fn updateStartRow(self: *Self, rows: u16, prev_rows: u16) !void {
    if (self.start_row == 1) return;

    const prev_start_row = self.start_row;
    const possible_max_rows = rows -| self.start_row -| 2;

    // Size decreased and cursor needs to increase
    if (prev_rows >= rows and possible_max_rows < self.max_rows) {
        self.start_row = 1;
        try Self.setCursor(1, 1);
    }

    // Size increased, start row shifted up
    else if (prev_rows < rows) {
        self.start_row += rows - prev_rows;
        try Self.scrollAndSetCursor(
            self.start_row - prev_start_row,
            self.start_row,
            1,
        );
    }
}

fn handleClear(self: *Self) !bool {
    // On clearing terminal screen (ctrl-k), cursor position
    // is reset to row 1.
    const position = try terminal.getCursorPosition();
    if (position.row != 1) {
        return false;
    }

    self.start_row = position.row;
    self.updateMaxRows();
    return true;
}

fn updateMaxRows(self: *Self) void {
    // Max rows used for printing
    // - first `- 1`  to adjust for 1 based index
    // - second `- 1` to prevent scroll by print on last line
    self.max_rows = self.size.rows - (self.start_row - 1) - 1;
}

fn scrollAndSetCursor(lines: u16, row: u16, col: u16) !void {
    // Scroll up and set cursor postion
    var obuf: [64]u8 = undefined;
    const slc = try std.fmt.bufPrint(
        &obuf,
        "\x1b[{d}S\x1b[{d},{d}H",
        .{ lines, row, col },
    );
    _ = try posix.write(posix.STDERR_FILENO, slc);
}

fn setCursor(row: u16, col: u16) !void {
    // Scroll up and set cursor postion
    var obuf: [64]u8 = undefined;
    const slc = try std.fmt.bufPrint(
        &obuf,
        "\x1b[{d},{d}H",
        .{ row, col },
    );
    _ = try posix.write(posix.STDERR_FILENO, slc);
}
