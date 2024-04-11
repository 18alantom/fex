/// Viewport is responsible for setting the terminal bounds within
/// which to display the contents of app.
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
start_row: u16 = 1, // 1 based index

const Self = @This();

pub fn init() !Self {
    try terminal.enableRawMode();
    return .{
        .max_rows = 1,
        .start_row = 1,
        .size = terminal.Size{ .cols = 1, .rows = 1 },
        .position = terminal.Position{ .col = 1, .row = 1 },
    };
}

pub fn deinit(_: *Self) void {
    terminal.disableRawMode() catch {};
}

pub fn setBounds(self: *Self) !void {
    // Note: terminal indices start from 1
    // Hence top left is 1,1
    self.size = terminal.getTerminalSize();
    var cursor_position = try terminal.getCursorPosition();
    self.position = try Self.getAdjustedPosition(self.size, cursor_position);

    // Max rows used for printing
    // - first `- 1`  to adjust for 1 based index
    // - second `- 1` to prevent scroll by print on last line
    self.max_rows = self.size.rows - (self.position.row - 1) - 1;
    self.start_row = self.position.row;
}

fn getAdjustedPosition(size: terminal.Size, cursor_position: terminal.Position) !terminal.Position {
    const min_rows = @min(size.rows / 2, 24);

    // Available rows below the cursor
    // - first `- 1`  to adjust for 1 based index
    // - second `- 1` to prevent scroll by print on last line
    const rows_below = size.rows - (cursor_position.row - 1) - 1;
    if (rows_below >= min_rows) {
        return cursor_position;
    }

    // Adjust Position: shift prompt (and cursor) up with newlines
    var scroll_up = min_rows - rows_below;
    var row = size.rows - min_rows;
    var col = cursor_position.col;

    // Scroll up and set cursor postion
    var obuf: [1024]u8 = undefined;
    var slc = try std.fmt.bufPrint(
        &obuf,
        "\x1b[{d}S\x1b[{d},{d}H",
        .{ scroll_up, row, col },
    );
    _ = try os.write(os.STDOUT_FILENO, slc);

    return terminal.Position{ .row = row, .col = col };
}
