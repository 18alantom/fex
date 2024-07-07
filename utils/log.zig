const std = @import("std");
const utils = @import("../utils.zig");

var stdout_mutex = std.Thread.Mutex{};

pub fn getStdoutLogMutex() *std.Thread.Mutex {
    return &stdout_mutex;
}

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_text = switch (level) {
        .err => "\x1b[31mERROR",
        .warn => "\x1b[33mWARNING",
        .info => "\x1b[34mINFO",
        .debug => "\x1b[36mDEBUG",
    };

    const scope_text = switch (scope) {
        std.log.default_log_scope => "",
        .app => "\x1b[39m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .apputils => "\x1b[39m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .input => "\x1b[32m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .state => "\x1b[33m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .terminal => "\x1b[33m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .string => "\x1b[34m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .treeview => "\x1b[34m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .actions => "\x1b[35m(" ++ @tagName(scope) ++ ")\x1b[m ",
        .view => "\x1b[35m(" ++ @tagName(scope) ++ ")\x1b[m ",
        else => "\x1b[1m(" ++ @tagName(scope) ++ ")\x1b[m ",
    };

    const prefix = level_text ++ "\x1b[m " ++ scope_text;

    // Print the message to stderr, silently ignoring any errors
    getStdoutLogMutex().lock();
    defer getStdoutLogMutex().unlock();

    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(prefix ++ format ++ "\n", args) catch return;
}
