const std = @import("std");

const fs = std.fs;
const heap = std.heap;
const mem = std.mem;
const io = std.io;
const os = std.os;

pub const Action = enum {
    up,
    down,
    left,
    right,
    select,
    help,
    quit,
    unknown,
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

pub fn readAction(self: *Self, buf: []u8) !Action {
    const value = try self.read(buf);
    return getAction(value);
}

pub fn getAction(value: []u8) Action {
    if (value.len == 1) {
        return getSingleCharMappedAction(value[0]);
    }

    if (value.len == 3) {
        return getTripleCharMappedAction(value);
    }
    return Action.unknown;
}

fn getSingleCharMappedAction(char: u8) Action {
    return switch (char) {
        // Help chars
        '?' => Action.help,
        'H' => Action.help,
        // Directional chars
        'h' => Action.left,
        'j' => Action.down,
        'k' => Action.up,
        'l' => Action.right,
        // Quit chars
        'q' => Action.quit,
        3 => Action.quit, // Ctrl-C
        4 => Action.quit, // Ctrl-D
        // Misc control chars
        10 => Action.select,
        // Unknown
        else => Action.unknown,
    };
}

fn getTripleCharMappedAction(chars: []u8) Action {
    // Up Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 65 })) {
        return Action.up;
    }

    // Down Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 66 })) {
        return Action.down;
    }

    // Right Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 67 })) {
        return Action.right;
    }

    // Left Arrow
    if (mem.eql(u8, chars, &[_]u8{ 27, 91, 68 })) {
        return Action.left;
    }

    return Action.unknown;
}
