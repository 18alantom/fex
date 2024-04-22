const std = @import("std");
const utils = @import("../utils.zig");
const Stat = @import("./Stat.zig");

const libc = @cImport({
    @cInclude("sys/time.h");
});

const fmt = std.fmt;

// Item Type
const d = "\x1b[34;1md\x1b[m"; // Blue 'd' for dir
const l = "\x1b[36;1ml\x1b[m"; // Cyan 'l' for link
const b = "\x1b[31;1ml\x1b[m"; // Red 'b' for block
const c = "\x1b[33;1ml\x1b[m"; // Yellow 'c' for char

// Item Perms
const x = "\x1b[32;1mx\x1b[m"; // Green 'x' for exec
const w = "\x1b[33;1mw\x1b[m"; // Yellow 'w' for write
const r = "\x1b[31;1mr\x1b[m"; // Red 'r' for read
const dash = "\x1b[2m-\x1b[m";

pub fn size(stat: Stat, buf: []u8) ![]u8 {
    const suffix = getSizeSuffix(stat.size);
    if (suffix == 'X') {
        return try std.fmt.bufPrint(buf, "2LRG ", .{});
    }

    const bytes_u: u64 = @intCast(@max(0, stat.size));
    if (stat.size < 999) {
        return try std.fmt.bufPrint(buf, "{d:4.0} ", .{bytes_u});
    }

    const trunc = @round(getTruncated(stat.size) * 10) / 10;
    if (trunc < 10) {
        return try std.fmt.bufPrint(buf, "{d:3.1}{c} ", .{ trunc, suffix });
    }

    return try std.fmt.bufPrint(buf, "{d:3.0}{c} ", .{ trunc, suffix });
}

fn getSizeSuffix(bytes: i64) u8 {
    if (bytes < 1_000) return ' ';
    if (bytes < 1_000_000) return 'k';
    if (bytes < 1_000_000_000) return 'M';
    if (bytes < 1_000_000_000_000) return 'G';
    if (bytes < 1_000_000_000_000_000) return 'T';
    if (bytes < 1_000_000_000_000_000_000) return 'P';
    if (bytes < 1_000_000_000_000_000_000_000) return 'E';
    return 'X';
}

fn getTruncated(bytes: i64) f64 {
    var bytes_f = @max(@as(f64, @floatFromInt(bytes)), 0);
    if (bytes_f < 1_000) return bytes_f;
    if (bytes_f < 1_000_000) return bytes_f / 1_000;
    if (bytes_f < 1_000_000_000) return bytes_f / 1_000_000;
    if (bytes_f < 1_000_000_000_000) return bytes_f / 1_000_000_000;
    if (bytes_f < 1_000_000_000_000_000) return bytes_f / 1_000_000_000_000;
    if (bytes_f < 1_000_000_000_000_000_000) return bytes_f / 1_000_000_000_000_000;
    if (bytes_f < 1_000_000_000_000_000_000_000) return bytes_f / 1_000_000_000_000_000_000;
    return bytes_f;
}

pub fn mode(stat: Stat, buf: []u8) ![]u8 {
    // User perms
    const exec_user = if (stat.hasUserExec()) x else dash; // & 0o100
    const write_user = if (stat.hasUserWrite()) w else dash; // & 0o200
    const read_user = if (stat.hasUserRead()) r else dash; // & 0o400
    // Group perms
    const exec_group = if (stat.hasGroupExec()) x else dash; // & 0o10
    const write_group = if (stat.hasGroupWrite()) w else dash; // & 0o20
    const read_group = if (stat.hasGroupRead()) r else dash; // & 0o40
    // Other perms
    const exec_other = if (stat.hasOtherExec()) x else dash; // & 0o1
    const write_other = if (stat.hasOtherWrite()) w else dash; // & 0o2
    const read_other = if (stat.hasOtherRead()) r else dash; // & 0o4

    return fmt.bufPrint(buf, "{s}{s}{s}{s}{s}{s}{s}{s}{s}{s} ", .{
        itemType(stat),
        // User
        exec_user,
        write_user,
        read_user,
        // Group
        exec_group,
        write_group,
        read_group,
        // Other
        exec_other,
        write_other,
        read_other,
    });
}

fn itemType(stat: Stat) []const u8 {
    if (stat.isDir()) {
        return d;
    }

    if (stat.isLink()) {
        return l;
    }

    if (stat.isChr()) {
        return c;
    }

    if (stat.isBlock()) {
        return b;
    }

    return " ";
}

pub fn time(stat: Stat, time_type: Stat.TimeType, buf: []u8) []u8 {
    const sec = switch (time_type) {
        .atime => stat.atime_sec,
        .ctime => stat.ctime_sec,
        .mtime => stat.mtime_sec,
    };

    const pre_format = "%d %b";
    const suf_format = if (isCurrentYear(sec)) "%H:%M" else "%Y";

    var ibuf: [32]u8 = undefined;
    var islc = utils.strftime(pre_format, sec, &ibuf);
    const pre_wlen = utils.lpad(islc, 6, ' ', buf).len;

    buf[pre_wlen] = ' ';

    islc = utils.strftime(suf_format, sec, &ibuf);
    const suf_wlen = utils.lpad(islc, 5, ' ', buf[(pre_wlen + 1)..]).len;

    return buf[0..(pre_wlen + 1 + suf_wlen)];
}

fn isCurrentYear(sec: isize) bool {
    const now = libc.time(null);
    return year(sec) == year(now);
}

fn year(sec: isize) isize {
    return @divFloor(sec, 3600 * 24 * 365) + 1970;
}
