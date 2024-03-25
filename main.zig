const std = @import("std");
const App = @import("./app/App.zig");

const fs = std.fs;
const mem = std.mem;
const heap = std.heap;
const os = std.os;

const print = std.debug.print;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try exe(
        allocator,
        getRoot(),
    );
}

fn getRoot() []const u8 {
    var args_iter = std.process.args();
    if (!args_iter.skip()) {
        return ".";
    }

    if (args_iter.next()) |r| {
        return r;
    }

    return ".";
}

fn exe(allocator: mem.Allocator, root: []const u8) !void {
    var app = try App.init(allocator, root);
    defer app.deinit();
    try app.run();
}

test "app" {
    std.debug.print("\n", .{});
    // TODO: run test on different thread, send inputs
    try exe(std.testing.allocator, ".");
}
