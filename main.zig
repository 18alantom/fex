const std = @import("std");
const builtin = @import("builtin");

const App = @import("./app/App.zig");
const args = @import("./app/args.zig");
const utils = @import("./utils.zig");

const fs = std.fs;
const mem = std.mem;
const heap = std.heap;
const os = std.os;

pub const std_options = .{
    .log_level = if (builtin.mode == .Debug) .debug else .err,
    .logFn = utils.log.logFn,
};

pub fn main() !void {
    var config: App.Config = .{ .root = "." };
    try args.setConfigFromEnv(&config);

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

fn exe(allocator: mem.Allocator, config: *App.Config) !void {
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
