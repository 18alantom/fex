const std = @import("std");
const fs = std.fs;

const print = std.debug.print;

fn listdir(dir: fs.Dir) !void {
    var iter_dir = try dir.openIterableDir(".", .{});
    defer iter_dir.close();

    var list = iter_dir.iterate();
    while (list.next() catch return) |entry| {
        print("{s} {any}\n", .{ entry.name, entry.kind });
    }
}

fn printabs(dir: fs.Dir) !void {
    var buf: [1024]u8 = undefined;
    print("{s}\n", .{
        try dir.realpath(".", &buf),
    });
}
