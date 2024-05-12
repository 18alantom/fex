const std = @import("std");
const Tui = @import("tui.zig");

const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;

const libc = @cImport({
    @cInclude("time.h");
});

pub const os = @import("./utils/os.zig");
pub const log = @import("./utils/log.zig");
pub const string = @import("./utils/string.zig");

pub const eql = string.eql;
pub const lpad = string.lpad;
pub const split = string.split;
pub const repeat = string.repeat;

pub const CharArray = std.ArrayList(u8);

pub fn strftime(format: []const u8, sec: isize, buf: []u8) []u8 {
    const time_info = libc.localtime(&sec);
    const wlen = libc.strftime(
        buf.ptr,
        buf.len,
        @ptrCast(format.ptr),
        time_info,
    );
    return buf[0..wlen];
}

pub fn isCurrentYear(sec: isize) bool {
    const now = libc.time(null);
    return year(sec) == year(now);
}

fn year(sec: isize) isize {
    return @divFloor(sec, 3600 * 24 * 365) + 1970;
}

pub fn FieldType(comptime T: type, comptime name: []const u8) type {
    comptime std.debug.assert(@hasField(T, name));
    inline for (@typeInfo(T).Struct.fields) |f| {
        if (std.mem.eql(u8, f.name, name)) {
            return f.type;
        }
    }

    unreachable;
}
