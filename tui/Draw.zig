const std = @import("std");
const terminal = @import("terminal.zig");

const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;
const testing = std.testing;

const VLineConfig = struct {
    col: usize = 0,
    row: usize = 0,
    len: usize = 4,
    char: []const u8 = "\u{2502}",
    style: []const u8 = "",
};

const HLineConfig = struct {
    col: usize = 0,
    row: usize = 0,
    len: usize = 4,
    char: []const u8 = "\u{2500}",
    style: []const u8 = "",
};

const StringConfig = struct {
    col: usize = 0,
    row: usize = 0,
    style: []const u8 = "",
};

const BoxChars = struct {
    // Borders
    tb: []const u8 = "\u{2500}", // top border
    bb: []const u8 = "\u{2500}", // bottom border
    lb: []const u8 = "\u{2502}", // left border
    rb: []const u8 = "\u{2502}", // right border

    // Vertices
    tlv: []const u8 = "\u{250C}", // top left vertex
    trv: []const u8 = "\u{2510}", // top right vertex
    brv: []const u8 = "\u{2518}", // bottom right vertex
    blv: []const u8 = "\u{2514}", // bottom left vertex
};

const BoxStyles = struct {
    // Borders
    tb: []const u8 = "", // top border
    bb: []const u8 = "", // bottom border
    lb: []const u8 = "", // left border
    rb: []const u8 = "", // right border

    // Vertices
    tlv: []const u8 = "", // top left vertex
    trv: []const u8 = "", // top right vertex
    brv: []const u8 = "", // bottom right vertex
    blv: []const u8 = "", // bottom left vertex
};

const BoxConfig = struct {
    col: usize = 0,
    row: usize = 0,
    width: usize = 4, // number of horizontal border chars, if 0 then only vertices
    height: usize = 4, // number of vertical border chars, if 0 then only vertices
    chars: BoxChars = .{},
    styles: BoxStyles = .{},
    style: []const u8 = "", // common style, overriden if `styles.value` is set.
};

writer: fs.File.Writer,

const Self = @This();

pub fn vline(self: *const Self, config: VLineConfig) !void {
    if (config.len == 0) {
        return;
    }

    for (0..config.len) |i| {
        if (config.style.len > 0) {
            _ = try self.writer.print("\x1b[{d};{d}H{s}{s}\x1b[m", .{
                config.row + i,
                config.col,
                config.style,
                config.char,
            });
        } else {
            _ = try self.writer.print("\x1b[{d};{d}H{s}", .{
                config.row + i,
                config.col,
                config.char,
            });
        }
    }
}

pub fn hline(self: *const Self, config: HLineConfig) !void {
    if (config.len == 0) {
        return;
    }

    if (config.style.len > 0) {
        _ = try self.writer.print("{s}", .{config.style});
    }

    // TODO: Execute using a single write
    for (0..config.len) |i| {
        _ = try self.writer.print("\x1b[{d};{d}H{s}", .{
            config.row,
            config.col + i,
            config.char,
        });
    }

    if (config.style.len > 0) {
        _ = try self.writer.write("\x1b[m");
    }
}

pub fn box(self: *const Self, config: BoxConfig) !void {
    const c = config.col;
    const r = config.row;
    const w = config.width;
    const h = config.height;
    const bs = getBoxStyle(config);
    const ch = config.chars;

    // top left vertex
    try self.string(ch.tlv, .{ .row = r, .col = c, .style = bs.tlv });

    // top right vertex
    try self.string(ch.trv, .{ .row = r, .col = c + w + 1, .style = bs.trv });

    // bottom left vertex
    try self.string(ch.blv, .{ .row = r + h + 1, .col = c, .style = bs.blv });

    // bottom right vertex
    try self.string(ch.brv, .{ .row = r + h + 1, .col = c + w + 1, .style = bs.brv });

    // top border
    try self.hline(.{ .col = c + 1, .row = r, .len = w, .char = ch.tb, .style = bs.tb });

    // bottom border
    try self.hline(.{ .col = c + 1, .row = r + h + 1, .len = w, .char = ch.bb, .style = bs.bb });

    // left border
    try self.vline(.{ .col = c, .row = r + 1, .len = h, .char = ch.lb, .style = bs.lb });

    // right border
    try self.vline(.{ .col = c + w + 1, .row = r + 1, .len = h, .char = ch.rb, .style = bs.rb });
}

fn getBoxStyle(config: BoxConfig) BoxStyles {
    const style = config.style;
    const styles = config.styles;
    return .{
        // Borders
        .tb = if (styles.tb.len > 0) styles.tb else style,
        .bb = if (styles.bb.len > 0) styles.bb else style,
        .lb = if (styles.lb.len > 0) styles.lb else style,
        .rb = if (styles.rb.len > 0) styles.rb else style,
        // Vertices
        .tlv = if (styles.tlv.len > 0) styles.tlv else style,
        .trv = if (styles.trv.len > 0) styles.trv else style,
        .blv = if (styles.blv.len > 0) styles.blv else style,
        .brv = if (styles.brv.len > 0) styles.brv else style,
    };
}

pub fn string(
    self: *const Self,
    str: []const u8,
    config: StringConfig,
) !void {
    if (config.style.len > 0) {
        _ = try self.writer.print("\x1b[{d};{d}H{s}{s}\x1b[m", .{ config.row, config.col, config.style, str });
    } else {
        _ = try self.writer.print("\x1b[{d};{d}H{s}", .{ config.row, config.col, str });
    }
}

pub fn print(self: *const Self, str: []const u8, style: []const u8) !void {
    _ = try self.writer.print("\x1b[{s}{s}\x1b[m", .{ style, str });
}

pub fn println(self: *const Self, str: []const u8, style: []const u8) !void {
    _ = try self.writer.print("\x1b[{s}{s}\x1b[m\n", .{ style, str });
}

pub fn moveCursor(self: *const Self, row: usize, col: usize) !void {
    _ = try self.writer.print("\x1b[{d};{d}H", .{ row, col });
}

pub fn saveCursor(self: *const Self) !void {
    _ = try self.writer.write("\x1b[s");
}

pub fn loadCursor(self: *const Self) !void {
    _ = try self.writer.write("\x1b[u");
}

pub fn hideCursor(self: *const Self) !void {
    _ = try self.writer.write("\x1b[?25l");
}

pub fn showCursor(self: *const Self) !void {
    _ = try self.writer.write("\x1b[?25h");
}

/// Clear the screen and set cursor to the top left position.
pub fn clearScreen(self: *const Self) !void {
    _ = try self.writer.write("\x1b[2J\x1b[H");
}

/// Clear N lines from the terminal screen off the bottom.
pub fn clearNLines(self: *const Self, n: u16) !void {
    const size = terminal.getTerminalSize();
    var buf: [128]u8 = undefined;
    var slc = try fmt.bufPrint(&buf, "\x1b[{d}H\x1b[{d}A\x1b[0J", .{ size.rows, n });
    _ = try self.writer.write(slc);
}

pub fn clearLinesBelow(self: *const Self, row: u16) !void {
    var buf: [128]u8 = undefined;
    var slc = try fmt.bufPrint(&buf, "\x1b[{d};0H\x1b[0J", .{row});
    _ = try self.writer.write(slc);
}
