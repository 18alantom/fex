const std = @import("std");
const Tui = @import("tui.zig");

const fs = std.fs;
const fmt = std.fmt;
const unicode = std.unicode;

const libc = @cImport({
    @cInclude("sys/time.h");
});

const print = std.debug.print;

pub const os = @import("./utils/os.zig");

/// Returns width of a grapheme in terms of number of characters required to display it
/// assuming a monospace font.
pub fn strWidth(str: []const u8) !usize {
    var total: isize = 0;
    var i: usize = 0;
    while (true) {
        const b = str[i];

        // Code points are u21 values, cp_len is number of bytes required to represent
        // a single code point, i.e. the next [i..i + cp_len] bytes belong to the
        // current code point.
        const cp_len = switch (b) {
            0b0000_0000...0b0111_1111 => 1,
            0b1100_0000...0b1101_1111 => 2,
            0b1110_0000...0b1110_1111 => 3,
            0b1111_0000...0b1111_0111 => 4,
            else => unreachable,
        };
        i += cp_len;

        // Backspace and delete values
        if (b == 8 or b == 127) {
            total -= 1;
            continue;
        } else if (b < 32) {
            continue;
        }

        total += 1;
    }

    // TODO: estimate width of graphemes of multiple code points.
    return if (total > 0) @intCast(total) else 0;
}

/// Repeats `str` `reps` number of time into the the given buffer `buf`
pub fn repeat(buf: []u8, str: []const u8, reps: usize) []u8 {
    for (0..reps) |i| {
        const s = i * str.len;
        const e = (i + 1) * str.len;

        @memcpy(buf[s..e], str);
    }

    return buf[0 .. str.len * reps];
}

pub fn strftime(format: []const u8, sec: isize, buf: []u8) []u8 {
    var time_info = libc.localtime(&sec);
    const wlen = libc.strftime(
        buf.ptr,
        buf.len,
        @ptrCast(format.ptr),
        time_info,
    );
    return buf[0..wlen];
}

pub fn lpad(str: []const u8, len: usize, pad: u8, buf: []u8) []u8 {
    const diff = len -| str.len;
    if (diff == 0) {
        @memcpy(buf[0..str.len], str);
        return buf[0..str.len];
    }

    @memset(buf[0..diff], pad);
    @memcpy(buf[diff..(diff + str.len)], str);
    return buf[0..(diff + str.len)];
}
