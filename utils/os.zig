const builtin = @import("builtin");
const std = @import("std");
const process = std.process;

pub fn open(path: []const u8) !void {
    switch (builtin.os.tag) {
        .macos => try openMacOs(path),
        else => return,
    }
}

fn openMacOs(path: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var argv = try allocator.alloc([]const u8, 2);
    defer allocator.free(argv);
    argv[0] = "open";
    argv[1] = path;

    try run(argv, allocator);
}

pub fn run(argv: [][]const u8, allocator: std.mem.Allocator) !void {
    var child = process.Child.init(argv, allocator);
    child.stdout_behavior = .Close;
    child.stderr_behavior = .Close;
    _ = try child.spawnAndWait();
}
