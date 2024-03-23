const std = @import("std");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const io = std.io;
const os = std.os;

pub const Key = enum {
    up_arrow,
    down_arrow,
    left_arrow,
    right_arrow,
    enter,
    question,
    fslash,
    h,
    j,
    k,
    l,
    q,
    C,
    E,
    G,
    cd,
    rm,
    mv,
    gg,
    unknown,
    ctrl_c,
    ctrl_d,
    // numerics
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
};

const print = std.debug.print;

reader: fs.File.Reader,

const Self = @This();

pub fn read(self: *Self, buf: []u8) ![]u8 {
    const size = try self.reader.read(buf);
    if (size == 0) {
        return error.EndOfStream;
    }

    return buf[0..size];
}

pub fn readByte(self: *Self) !u8 {
    return self.reader.readByte();
}

pub fn readUntil(self: *Self, buf: []u8, delimiter: u8, max: usize) []u8 {
    var fbs = io.fixedBufferStream(buf);
    try self.reader.streamUntilDelimiter(
        fbs.writer(),
        delimiter,
        max,
    );
    return fbs.getWritten();
}

pub fn readKeys(self: *Self) !Key {
    var buf: [256]u8 = undefined;
    var prev: ?u8 = null;
    while (true) {
        const value = try self.read(&buf);
        if (value.len == 3) {
            return getTripleCharMappedAction(value);
        }

        if (value.len != 1) {
            return Key.unknown;
        }

        const char = value[0];
        return switch (char) {
            // Help and other chars
            '?' => Key.question,
            '/' => Key.fslash,
            // Directional chars
            'h' => Key.h,
            'j' => Key.j,
            'k' => Key.k,
            'l' => Key.l,
            // Navigation chars
            'G' => Key.G,
            'g' => {
                if (prev == 'g') return Key.gg;
                prev = 'g';
                continue;
            },
            // Functional chars
            'c' => {
                if (prev != null) return Key.unknown;
                prev = 'c';
                continue;
            },
            'd' => {
                if (prev == 'c') return Key.cd;
                return Key.unknown;
            },
            'm' => {
                if (prev == 'r') return Key.rm;
                if (prev != null) return Key.unknown;
                prev = 'm';
                continue;
            },
            'v' => {
                if (prev == 'm') return Key.mv;
                return Key.unknown;
            },
            'r' => {
                if (prev != null) return Key.unknown;
                prev = 'r';
                continue;
            },
            // Toggles
            'C' => Key.C,
            'E' => Key.E,
            // Numerics
            '1' => Key.one,
            '2' => Key.two,
            '3' => Key.three,
            '4' => Key.four,
            '5' => Key.five,
            '6' => Key.six,
            '7' => Key.seven,
            '8' => Key.eight,
            '9' => Key.nine,
            // Quit chars
            'q' => Key.q,
            3 => Key.ctrl_c, // Ctrl-C
            4 => Key.ctrl_d, // Ctrl-D
            // Misc control chars
            10 => Key.enter,
            // Unknown
            else => Key.unknown,
        };
    }
}

fn getTripleCharMappedAction(chars: []u8) Key {
    // Up Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 65 })) {
        return Key.up_arrow;
    }

    // Down Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 66 })) {
        return Key.down_arrow;
    }

    // Right Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 67 })) {
        return Key.right_arrow;
    }

    // Left Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 68 })) {
        return Key.left_arrow;
    }

    return Key.unknown;
}
