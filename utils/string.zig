const std = @import("std");
const BufferWriter = @import("./BufferWriter.zig");
const log = std.log.scoped(.string);

const mem = std.mem;
const ascii = std.ascii;

pub const SearchQuery = struct {
    fuzzy_search: bool,
    ignore_case: bool,
    query: []const u8,
};

pub fn search(
    candidate: []const u8,
    search_query: *const SearchQuery,
) bool {
    if (search_query.fuzzy_search) {
        return fuzzySearch(candidate, search_query.query, search_query.ignore_case);
    }

    return regularSearch(candidate, search_query.query, search_query.ignore_case);
}

pub fn regularSearch(candidate: []const u8, query: []const u8, ignore_case: bool) bool {
    var i: usize = 0;
    while (i < query.len) : (i += 1) {
        const should_ignore_case = ignore_case and !ascii.isUpper(query[i]);
        const c = if (should_ignore_case) ascii.toLower(candidate[i]) else candidate[i];
        const q = if (should_ignore_case) ascii.toLower(query[i]) else query[i];
        if (c != q) return false;
    }

    return true;
}

pub fn fuzzySearch(candidate: []const u8, query_: []const u8, ignore_case: bool) bool {
    var query = query_;
    const matches_start = doesMatchStart(candidate, query, ignore_case);
    const matches_end = doesMatchEnd(candidate, query, ignore_case);

    if (matches_start == .no_match or matches_end == .no_match) return false;
    if (matches_start == .match) query = query[1..];
    if (matches_end == .match) query = query[0..(query.len -| 1)];
    if (query.len > candidate.len) return false;

    var c_i: usize = 0;
    var q_i: usize = 0;

    while (true) {
        if (q_i >= query.len) return true;
        if (c_i >= candidate.len) return false;

        const should_ignore_case = ignore_case and !ascii.isUpper(query[q_i]);
        const c = if (should_ignore_case) ascii.toLower(candidate[c_i]) else candidate[c_i];
        const q = if (should_ignore_case) ascii.toLower(query[q_i]) else query[q_i];

        if (c != q) {
            c_i += 1;
            continue;
        }

        c_i += 1;
        q_i += 1;
    }

    return false;
}

const highlight = .{
    .start = "\x1b[33m",
    .end = "\x1b[m",
};
pub fn searchHighlight(buffer: []u8, candidate: []const u8, search_query: *const SearchQuery) ![]const u8 {
    if (search_query.query.len == 0) {
        return candidate;
    }

    if (search_query.fuzzy_search) {
        return try fuzzySearchHighlight(buffer, candidate, search_query.query, search_query.ignore_case);
    }

    return try regularSearchHighlight(buffer, candidate, search_query.query, search_query.ignore_case);
}

pub fn regularSearchHighlight(buffer: []u8, candidate: []const u8, query: []const u8, ignore_case: bool) ![]const u8 {
    var bw = BufferWriter{ .buffer = buffer };
    var is_match = true;

    var i: usize = 0;
    while (i < query.len) : (i += 1) {
        const should_ignore_case = ignore_case and !ascii.isUpper(query[i]);
        const c = if (should_ignore_case) ascii.toLower(candidate[i]) else candidate[i];
        const q = if (should_ignore_case) ascii.toLower(query[i]) else query[i];

        const c_ = candidate[i];
        defer bw.writeByte(c_) catch {};

        if (c != q) {
            is_match = false;
            break;
        }

        if (i == 0) {
            try bw.write(highlight.start);
        }
    }

    if (!is_match) {
        return candidate;
    }

    try bw.write(highlight.end);
    while (i < candidate.len) : (i += 1) {
        try bw.writeByte(candidate[i]);
    }

    return bw.string();
}

pub fn fuzzySearchHighlight(buffer: []u8, candidate: []const u8, query_: []const u8, ignore_case: bool) ![]const u8 {
    var query = query_;
    const matches_start = doesMatchStart(candidate, query, ignore_case);
    const matches_end = doesMatchEnd(candidate, query, ignore_case);

    if (matches_start == .no_match or matches_end == .no_match) return candidate;
    if (matches_start == .match) query = query[1..];
    if (matches_end == .match) query = query[0..(query.len -| 1)];
    if (query.len > candidate.len) return candidate;

    var bw = BufferWriter{ .buffer = buffer };
    var c_i: usize = 0;
    var q_i: usize = 0;
    var in_highlight = false;

    while (true) {
        if (q_i >= query.len) break;
        if (c_i >= candidate.len) break;

        const should_ignore_case = ignore_case and !ascii.isUpper(query[q_i]);
        const c = if (should_ignore_case) ascii.toLower(candidate[c_i]) else candidate[c_i];
        const q = if (should_ignore_case) ascii.toLower(query[q_i]) else query[q_i];

        const c_ = candidate[c_i];
        defer bw.writeByte(c_) catch {};

        if (c != q) {
            if (in_highlight) {
                in_highlight = false;
                try bw.write(highlight.end);
            }

            c_i += 1;
            continue;
        }

        if (!in_highlight) {
            in_highlight = true;
            try bw.write(highlight.start);
        }

        c_i += 1;
        q_i += 1;
    }

    if (in_highlight) {
        in_highlight = false;
        try bw.write(highlight.end);
    }

    while (c_i < candidate.len) : (c_i += 1) {
        try bw.writeByte(candidate[c_i]);
    }

    if (q_i >= query.len) {
        return bw.string();
    }

    return candidate;
}

const DoesMatch = enum { match, no_match, no_query };
/// '^' is used to match the starting character
fn doesMatchStart(candidate: []const u8, query: []const u8, ignore_case: bool) DoesMatch {
    const q_len = query.len;
    const c_len = candidate.len;

    if (q_len == 0 or (q_len >= 1 and query[0] != '^')) return .no_query;
    if (q_len == 1 or c_len == 0) return .no_match;
    std.debug.assert(q_len > 1 and query[0] == '^');

    const q = query[1];
    const should_ignore_case = ignore_case and !ascii.isUpper(q);
    const c = if (should_ignore_case) ascii.toLower(candidate[0]) else candidate[0];
    if (q == c) {
        return .match;
    }
    return .no_match;
}

/// '$' is used to match the ending character
fn doesMatchEnd(candidate: []const u8, query: []const u8, ignore_case: bool) DoesMatch {
    const q_len = query.len;
    const c_len = candidate.len;

    if (q_len == 0 or (q_len >= 1 and query[q_len - 1] != '$')) return .no_query;
    if (query.len == 1 or candidate.len == 0) return .no_match;
    std.debug.assert(query.len > 1 and query[q_len - 1] == '$');

    const q = query[q_len - 2];
    const should_ignore_case = ignore_case and !ascii.isUpper(q);
    const c = if (should_ignore_case) ascii.toLower(candidate[c_len - 1]) else candidate[c_len - 1];
    if (q == c) {
        return .match;
    }
    return .no_match;
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
    try testing.expect(regularSearch("hello", "Hello, World!", true));
    try testing.expect(regularSearch("Hello", "Hello, World!", false));

    try testing.expect(!regularSearch("hello", "Hello, World!", false));
    try testing.expect(!regularSearch("hello", "Hello, hello!", false));

    try testing.expect(fuzzySearch("hello", "Hello, hello!", false));
    try testing.expect(fuzzySearch("hello", "h.e.l.l.o.!", false));
    try testing.expect(fuzzySearch("hello", "H.e.L.l.O.!", true));

    try testing.expect(!fuzzySearch("hello", "H.L.l.O.!", true));
    try testing.expect(!fuzzySearch("hello", "h.e.L.l.O.!", false));
}
