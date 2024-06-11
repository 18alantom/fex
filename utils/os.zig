const builtin = @import("builtin");
const std = @import("std");
const process = std.process;

pub fn open(path: []const u8) !void {
    switch (builtin.os.tag) {
        .macos => openMacOs(path) catch {},
        .linux => openLinux(path) catch {},
        else => return,
    }
}

fn openMacOs(path: []const u8) !void {
    var argv = [_][]const u8{ "open", path };
    try run(&argv);
}

fn openLinux(path: []const u8) !void {
    var argv = [_][]const u8{ "xdg-open", path };
    try run(&argv);
}

pub fn run(argv: [][]const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Initialize child process
    var child = process.Child.init(argv, allocator);
    child.stdout_behavior = .Close;
    child.stderr_behavior = .Close;
    _ = try child.spawnAndWait();
}
