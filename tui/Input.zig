const std = @import("std");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const io = std.io;
const os = std.os;

pub const Key = enum {
    up,
    down,
    left,
    right,
    enter,
    question,
    fslash,
    q,
    gg,
    G,
    unknown,
    ctrl_c,
    ctrl_d,
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
            'h' => Key.left,
            'j' => Key.down,
            'k' => Key.up,
            'l' => Key.right,
            // Navigation chars
            'G' => Key.G,
            'g' => {
                if (prev == 'g') return Key.gg;
                prev = 'g';
                continue;
            },
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
        return Key.up;
    }

    // Down Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 66 })) {
        return Key.down;
    }

    // Right Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 67 })) {
        return Key.right;
    }

    // Left Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 68 })) {
        return Key.left;
    }

    return Key.unknown;
}
