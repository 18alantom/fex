const std = @import("std");
const tui = @import("./tui.zig");

const fs = std.fs;
const fmt = std.fmt;
const heap = std.heap;
const mem = std.mem;
const os = std.os;
const io = std.io;
const time = std.time;
const terminal = tui.terminal;

const print = std.debug.print;
const BW = tui.BufferedStdOut;
const Draw = tui.Draw;

pub fn main() !void {
    try terminal.enableRawMode();
    defer terminal.disableRawMode() catch {};

    var writer = BW.init();
    var draw = Draw{ .writer = writer };
    try draw.hideCursor();
    defer draw.showCursor() catch {};

    try manual(&draw);
}

pub fn manual(draw: *Draw) !void {
    var reader = io.getStdIn().reader();
    var char: u8 = 32;

    while (true) {
        const start = time.nanoTimestamp();
        try draw.moveCursor(0, 0);
        try fillScreenChar(char, draw.writer);

        const input_start = time.nanoTimestamp();
        while (true) {
            const b = try reader.readByte();
            switch (b) {
                'j' => char +|= 1,
                'k' => char -|= 1,
                'q' => return,
                else => continue,
            }

            break;
        }
        const input_end = time.nanoTimestamp();

        try draw.clearScreen();
        const input_diff = input_end - input_start;
        const diff: f64 = @floatFromInt((time.nanoTimestamp() - start) - input_diff);
        std.debug.print("total_time    : {d:8.3} µs\n\n", .{diff / 1000});
    }
}

pub fn fillScreenChar(char: u8, writer_: BW) !void {
    var writer = writer_;
    const c: u8 = switch (char) {
        0...32 => char + 32,
        33...126 => char,
        127...255 => (char % 32) + 32,
    };

    const size = terminal.getTerminalSize();
    writer.buffered();

    const start_fill = time.nanoTimestamp();
    for (0..size.rows) |r| {
        for (0..size.cols) |_| {
            _ = try writer.print("\x1b[{d}m{c}\x1b[0m", .{ (c +| r) % 7 + 31, c });
        }
        _ = try writer.write("\n");
    }
    const end_fill = time.nanoTimestamp();

    const bytes: f64 = @floatFromInt(writer.end);
    try writer.flushAndUnbuffered();
    const end_flush = time.nanoTimestamp();

    const diff_fill: f64 = @floatFromInt(end_fill - start_fill);
    const diff_flush: f64 = @floatFromInt(end_flush - end_fill);
    const rows: f64 = @floatFromInt(size.rows);

    std.debug.print("bytes_per_row : {d:8}\n", .{
        bytes / rows,
    });
    std.debug.print("fill_per_row  : {d:8.3} µs\n", .{
        (diff_fill / rows) / 1000,
    });
    std.debug.print("flush_per_row : {d:8.3} µs\n", .{
        (diff_flush / rows) / 1000,
    });
}
