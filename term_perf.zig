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

const FSStats = struct {
    bytes_per_row: f64,
    num_rows: f64,
    num_cols: f64,
    fill_per_row: f64,
    flush_per_row: f64,
};

const RenderStats = struct {
    bytes_per_row: f64,
    num_rows: f64,
    num_cols: f64,
    fill_per_row: f64,
    flush_per_row: f64,
    clear_screen: f64,
    fill_screen: f64,
    total: f64,
};
const TimeLog = std.ArrayList(RenderStats);
pub fn main() !void {
    try terminal.enableRawMode();
    defer terminal.disableRawMode() catch {};

    var writer = BW.init();
    var draw = Draw{ .writer = writer };
    try draw.hideCursor();
    defer draw.showCursor() catch {};

    var timelog = TimeLog.init(std.heap.page_allocator);
    defer timelog.deinit();

    try loop(&draw, false, &timelog);
    print_timelog(&timelog);
}

pub fn print_timelog(timelog: *TimeLog) void {
    var totals: RenderStats = .{
        .bytes_per_row = 0,
        .num_rows = 0,
        .num_cols = 0,
        .fill_per_row = 0,
        .flush_per_row = 0,
        .clear_screen = 0,
        .fill_screen = 0,
        .total = 0,
    };

    for (0..timelog.items.len) |i| {
        var log = timelog.items[i];
        totals.bytes_per_row += log.bytes_per_row;
        totals.num_rows += log.num_rows;
        totals.num_cols += log.num_cols;
        totals.fill_per_row += log.fill_per_row;
        totals.flush_per_row += log.flush_per_row;
        totals.clear_screen += log.clear_screen;
        totals.fill_screen += log.fill_screen;
        totals.total += log.total;
    }

    const len: f64 = @floatFromInt(timelog.items.len);
    std.debug.print("num_entries   : {d:14.0}\n", .{len});
    std.debug.print("num_rows      : {d:14.0}\n", .{totals.num_rows / len});
    std.debug.print("num_cols      : {d:14.0}\n", .{totals.num_cols / len});
    std.debug.print("bytes_per_row : {d:14.0} B\n", .{totals.bytes_per_row / len});
    std.debug.print("fill_per_row  : {d:14.3} µs\n", .{totals.fill_per_row / len});
    std.debug.print("flush_per_row : {d:14.3} µs\n", .{totals.flush_per_row / len});
    std.debug.print("clear_screen  : {d:14.3} µs\n", .{totals.clear_screen / len});
    std.debug.print("fill_screen   : {d:14.3} µs\n", .{totals.fill_screen / len});
    std.debug.print("average_total : {d:14.3} µs\n", .{totals.total / len});
    std.debug.print("total         : {d:14.3} ms\n", .{totals.total / 1000});
}

pub fn loop(draw: *Draw, is_manual: bool, timelog: *TimeLog) !void {
    var reader = io.getStdIn().reader();
    var char: u8 = 32;
    var total: usize = 0;

    while (true) {
        const start = time.nanoTimestamp();
        try draw.moveCursor(0, 0);

        const fs_start = time.nanoTimestamp();
        const fs_times = try fillScreenChar(char, draw.writer);
        const fs_end = time.nanoTimestamp();

        var input_diff: i128 = 0;
        if (is_manual) {
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
            input_diff = time.nanoTimestamp() - input_start;
        } else {
            char +|= 1;
            total +|= 1;
        }

        const clear_start = time.nanoTimestamp();
        try draw.clearScreen();
        const total_end = time.nanoTimestamp();

        const clear_diff: f64 = @floatFromInt(total_end - clear_start);
        const total_diff: f64 = @floatFromInt((total_end - start) - input_diff);
        const fs_diff: f64 = @floatFromInt(fs_end - fs_start);

        try timelog.append(.{
            .bytes_per_row = fs_times.bytes_per_row,
            .num_rows = fs_times.num_rows,
            .num_cols = fs_times.num_cols,
            .fill_per_row = fs_times.fill_per_row,
            .flush_per_row = fs_times.flush_per_row,
            .clear_screen = clear_diff / 1000,
            .fill_screen = fs_diff / 1000,
            .total = total_diff / 1000,
        });

        if (total == 256) break;
    }
}

pub fn fillScreenChar(char: u8, writer_: BW) !FSStats {
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
    try writer.flush();
    writer.unbuffered();
    const end_flush = time.nanoTimestamp();

    const diff_fill: f64 = @floatFromInt(end_fill - start_fill);
    const diff_flush: f64 = @floatFromInt(end_flush - end_fill);
    const cols: f64 = @floatFromInt(size.cols);
    const rows: f64 = @floatFromInt(size.rows);

    return .{
        .bytes_per_row = bytes / rows,
        .num_cols = cols,
        .num_rows = rows,
        .fill_per_row = (diff_fill / rows) / 1000,
        .flush_per_row = (diff_flush / rows) / 1000,
    };
}
