const std = @import("std");
const Stat = @import("./Stat.zig");

const fmt = std.fmt;

// Item Type
const d = "\x1b[34;1md\x1b[m"; // Blue 'd' for dir
const l = "\x1b[36;1ml\x1b[m"; // Cyan 'l' for link
const b = "\x1b[31;1ml\x1b[m"; // Red 'b' for block
const c = "\x1b[33;1ml\x1b[m"; // Yellow 'c' for char

// Item Perms
const x = "\x1b[32mx\x1b[m"; // Green 'x' for exec
const w = "\x1b[33mw\x1b[m"; // Yellow 'w' for write
const r = "\x1b[31mr\x1b[m"; // Red 'r' for read
const dash = "\x1b[2m-\x1b[m";

pub fn size(stat: Stat, obuf: []u8) ![]u8 {
    var raw_size = stat.size;
    var fmt_size = @max(@as(f64, @floatFromInt(raw_size)), 0);
    if (fmt_size < 1000) {
        return fmt.bufPrint(obuf, "{d:7} ", .{fmt_size});
    }

    if (fmt_size < 1_000_000) {
        fmt_size /= 1_000;
        return fmt.bufPrint(obuf, "{d:6.1}k ", .{fmt_size});
    }

    if (fmt_size < 1_000_000_000) {
        fmt_size /= 1_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}M ", .{fmt_size});
    }

    if (fmt_size < 1_000_000_000_000) {
        fmt_size /= 1_000_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}G ", .{fmt_size});
    }

    if (fmt_size < 1_000_000_000_000_000) {
        fmt_size /= 1_000_000_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}T ", .{fmt_size});
    }

    if (fmt_size < 1_000_000_000_000_000_000) {
        fmt_size /= 1_000_000_000_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}P ", .{fmt_size});
    }

    return fmt.bufPrint(obuf, "{d:7} ", .{0});
}

pub fn mode(stat: Stat, obuf: []u8) ![]u8 {
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

    return fmt.bufPrint(obuf, "{s}{s}{s}{s}{s}{s}{s}{s}{s}{s} ", .{
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
