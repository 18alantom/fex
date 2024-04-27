const std = @import("std");
const args = @import("./app/args.zig");
const App = @import("./app/App.zig");

const fs = std.fs;
const mem = std.mem;
const heap = std.heap;
const os = std.os;

pub fn main() !void {
    var config: args.Config = .{ .root = "." };
    // Returns true if arg has --help
    if (try args.setConfig(&config)) {
        return;
    }

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    try exe(
        allocator,
        &config,
    );
}

fn exe(allocator: mem.Allocator, config: *args.Config) !void {
    var app = try App.init(allocator, config);
    defer app.deinit();
    try app.run();
}

test "app" {
    // TODO: run test on different thread, send inputs
    std.debug.print("\n", .{});
    var config: args.Config = .{ .root = "." };
    try exe(std.testing.allocator, &config);
}
