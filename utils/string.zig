const std = @import("std");

const mem = std.mem;
const ascii = std.ascii;

pub fn search(query: []const u8, candidate: []const u8, ignore_case: bool) bool {
    var i: usize = 0;
    while (i < query.len) : (i += 1) {
        const c = if (ignore_case) ascii.toLower(candidate[i]) else candidate[i];
        const q = if (ignore_case) ascii.toLower(query[i]) else query[i];
        if (c != q) return false;
    }

    return true;
}

pub fn fuzzySearch(query: []const u8, candidate: []const u8, ignore_case: bool) bool {
    var c_i: usize = 0;
    var q_i: usize = 0;

    while (true) {
        if (q_i >= query.len) return true;
        if (c_i >= candidate.len) return false;

        const c = if (ignore_case) ascii.toLower(candidate[c_i]) else candidate[c_i];
        const q = if (ignore_case) ascii.toLower(query[q_i]) else query[q_i];

        if (c != q) {
            c_i += 1;
            continue;
        }

        c_i += 1;
        q_i += 1;
    }

    return false;
}

pub fn eql(a: []const u8, b: []const u8) bool {
    return mem.eql(u8, a, b);
}

pub fn split(buffer: []const u8, delimiter: []const u8) std.mem.SplitIterator(u8, .sequence) {
    return mem.splitSequence(u8, buffer, delimiter);
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

const testing = std.testing;
test "search" {
    try testing.expect(search("hello", "Hello, World!", true));
    try testing.expect(search("Hello", "Hello, World!", false));

    try testing.expect(!search("hello", "Hello, World!", false));
    try testing.expect(!search("hello", "Hello, hello!", false));

    try testing.expect(fuzzySearch("hello", "Hello, hello!", false));
    try testing.expect(fuzzySearch("hello", "h.e.l.l.o.!", false));
    try testing.expect(fuzzySearch("hello", "H.e.L.l.O.!", true));

    try testing.expect(!fuzzySearch("hello", "H.L.l.O.!", true));
    try testing.expect(!fuzzySearch("hello", "h.e.L.l.O.!", false));
}
