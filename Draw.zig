const std = @import("std");

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

const Color = enum(u8) {
    black = 0,
    red = 1,
    green = 2,
    yellow = 3,
    blue = 4,
    magenta = 5,
    cyan = 6,
    white = 7,
    default = 9,

    // Select alternative color scheme
    c256, // \x1b[38;5;{n}m
    rgb, // \x1b[38;2;{r};{g};{b}m
    none, // color string not applied
};

const StyleConfig = struct {
    bold: bool = false,
    faint: bool = false,
    italic: bool = false,
    underline: bool = false,
    blink: bool = false,
    inverse: bool = false,
    hidden: bool = false,
    strike: bool = false,

    // Foreground color
    fg: Color = .none,
    fg_n: u8 = 0, // 8bit ANSI colors
    fg_r: u8 = 0,
    fg_g: u8 = 0,
    fg_b: u8 = 0,

    // Background color
    bg: Color = .none,
    bg_n: u8 = 0, // 8bit ANSI colors
    bg_r: u8 = 0,
    bg_g: u8 = 0,
    bg_b: u8 = 0,
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

pub fn vline(self: *Self, config: VLineConfig) !void {
    try self._vline(config, true);
}
fn _vline(self: *Self, config: VLineConfig, return_cursor: bool) !void {
    if (config.len == 0) {
        return;
    }

    if (return_cursor) {
        self.saveCursor();
        defer self.loadCursor();
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

pub fn hline(self: *Self, config: HLineConfig) !void {
    try self._hline(config, true);
}
fn _hline(self: *Self, config: HLineConfig, return_cursor: bool) !void {
    if (config.len == 0) {
        return;
    }

    if (return_cursor) {
        self.saveCursor();
        defer self.loadCursor();
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

pub fn box(self: *Self, config: BoxConfig) !void {
    self.saveCursor();
    defer self.loadCursor();

    const c = config.col;
    const r = config.row;
    const w = config.width;
    const h = config.height;
    const bs = getBoxStyle(config);
    const ch = config.chars;

    // top left vertex
    try self.string(r, c, ch.tlv, bs.tlv, false);

    // top right vertex
    try self.string(r, c + w + 1, ch.trv, bs.trv, false);

    // bottom left vertex
    try self.string(r + h + 1, c, ch.blv, bs.blv, false);

    // bottom right vertex
    try self.string(r + h + 1, c + w + 1, ch.brv, bs.brv, false);

    // top border
    try self._hline(.{ .col = c + 1, .row = r, .len = w, .char = ch.tb, .style = bs.tb }, false);

    // bottom border
    try self._hline(.{ .col = c + 1, .row = r + h + 1, .len = w, .char = ch.bb, .style = bs.bb }, false);

    // left border
    try self._vline(.{ .col = c, .row = r + 1, .len = h, .char = ch.lb, .style = bs.lb }, false);

    // right border
    try self._vline(.{ .col = c + w + 1, .row = r + 1, .len = h, .char = ch.rb, .style = bs.rb }, false);
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
    self: *Self,
    row: usize,
    col: usize,
    val: []const u8,
    style: []const u8,
    return_cursor: bool,
) !void {
    if (return_cursor) {
        self.saveCursor();
        defer self.loadCursor();
    }

    if (style.len > 0) {
        _ = try self.writer.print("\x1b[{d};{d}H{s}{s}\x1b[m", .{ row, col, style, val });
    } else {
        _ = try self.writer.print("\x1b[{d};{d}H{s}", .{ row, col, val });
    }
}

pub fn moveCursor(self: *Self, row: usize, col: usize) !void {
    _ = try self.writer.print("\x1b[{d};{d}H", .{ row, col });
}

pub fn saveCursor(self: *Self) void {
    _ = self.writer.write("\x1b[s") catch {};
}

pub fn loadCursor(self: *Self) void {
    _ = self.writer.write("\x1b[u") catch {};
}

pub fn getStyle(buf: []u8, config: StyleConfig) ![]u8 {
    var slc = try fmt.bufPrint(buf, "\x1b[", .{});
    var index: usize = slc.len;

    if (config.bold) {
        slc = try fmt.bufPrint(buf[index..], "1;", .{});
        index += slc.len;
    }

    if (config.faint) {
        slc = try fmt.bufPrint(buf[index..], "2;", .{});
        index += slc.len;
    }

    if (config.italic) {
        slc = try fmt.bufPrint(buf[index..], "3;", .{});
        index += slc.len;
    }

    if (config.underline) {
        slc = try fmt.bufPrint(buf[index..], "4;", .{});
        index += slc.len;
    }

    if (config.blink) {
        slc = try fmt.bufPrint(buf[index..], "5;", .{});
        index += slc.len;
    }

    if (config.inverse) {
        slc = try fmt.bufPrint(buf[index..], "7;", .{});
        index += slc.len;
    }

    if (config.hidden) {
        slc = try fmt.bufPrint(buf[index..], "8;", .{});
        index += slc.len;
    }

    if (config.strike) {
        slc = try fmt.bufPrint(buf[index..], "9;", .{});
        index += slc.len;
    }

    if (config.fg == .c256) {
        slc = try fmt.bufPrint(buf[index..], "38;5;{d};", .{config.fg_n});
        index += slc.len;
    } else if (config.fg == .rgb) {
        slc = try fmt.bufPrint(buf[index..], "38;2;{d};{d};{d};", .{ config.fg_r, config.fg_g, config.fg_b });
        index += slc.len;
    } else if (config.fg != .none) {
        const n = @intFromEnum(config.fg);
        slc = try fmt.bufPrint(buf[index..], "{d};", .{n + 30});
        index += slc.len;
    }

    if (config.bg == .c256) {
        slc = try fmt.bufPrint(buf[index..], "48;5;{d};", .{config.bg_n});
        index += slc.len;
    } else if (config.bg == .rgb) {
        slc = try fmt.bufPrint(buf[index..], "48;2;{d};{d};{d};", .{ config.bg_r, config.bg_g, config.bg_b });
        index += slc.len;
    } else if (config.bg != .none) {
        const n = @intFromEnum(config.bg);
        slc = try fmt.bufPrint(buf[index..], "{d};", .{n + 40});
        index += slc.len;
    }

    // no styles were applied
    if (index == "\x1b[".len) {
        return buf[0..0];
    }

    _ = try fmt.bufPrint(buf[index - 1 ..], "m", .{});
    return buf[0..index];
}

test "getStyle" {
    var buf: [512]u8 = undefined;
    try testing.expect(
        mem.eql(u8, try Self.getStyle(&buf, .{}), ""),
    );

    try testing.expectEqualStrings(
        try Self.getStyle(&buf, .{ .bold = true }),
        "\x1b[1m",
    );

    try testing.expectEqualStrings(
        try Self.getStyle(&buf, .{
            .bold = true,
            .italic = true,
            .inverse = true,
        }),
        "\x1b[1;3;7m",
    );

    try testing.expectEqualStrings(
        try Self.getStyle(&buf, .{
            .bold = true,
            .italic = true,
            .inverse = true,
            .fg = .blue,
            .bg = .white,
        }),
        "\x1b[1;3;7;34;47m",
    );

    try testing.expectEqualStrings(
        try Self.getStyle(&buf, .{
            .bold = true,
            .fg = .rgb,
            .fg_r = 255,
            .fg_g = 121,
            .fg_b = 99,
        }),
        "\x1b[1;38;2;255;121;99m",
    );
}
