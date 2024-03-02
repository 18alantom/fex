const std = @import("std");

const fmt = std.fmt;
const testing = std.testing;

pub const Color = enum(u8) {
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

pub const StyleConfig = struct {
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

pub fn bufStyle(buf: []u8, config: StyleConfig) ![]u8 {
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

test "bufStyle" {
    var buf: [512]u8 = undefined;
    try testing.expectEqualStrings(
        try bufStyle(&buf, .{}),
        "",
    );

    try testing.expectEqualStrings(
        try bufStyle(&buf, .{ .bold = true }),
        "\x1b[1m",
    );

    try testing.expectEqualStrings(
        try bufStyle(&buf, .{
            .bold = true,
            .italic = true,
            .inverse = true,
        }),
        "\x1b[1;3;7m",
    );

    try testing.expectEqualStrings(
        try bufStyle(&buf, .{
            .bold = true,
            .italic = true,
            .inverse = true,
            .fg = .blue,
            .bg = .white,
        }),
        "\x1b[1;3;7;34;47m",
    );

    try testing.expectEqualStrings(
        try bufStyle(&buf, .{
            .bold = true,
            .fg = .rgb,
            .fg_r = 255,
            .fg_g = 121,
            .fg_b = 99,
        }),
        "\x1b[1;38;2;255;121;99m",
    );
}
