const std = @import("std");
const utils = @import("utils.zig");
const Tui = @import("Tui.zig");

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const time = std.time;
const mem = std.mem;

var sel: u8 = 0;
const options: [3][]const u8 = .{
    "One",
    "Two",
    "Three",
};

pub fn render(tui: *Tui) !void {
    try tui.clearScreen();
    _ = try tui.write("\x1b[1;34mSelect An Option (quit: q)\n\x1b[0m");

    for (options, 0..) |op, i| {
        if (sel == i) {
            try tui.writer.print("\x1b[1;35m▶ \x1b[1;33m{s}\x1b[0m\n", .{op});
        } else {
            try tui.writer.print("  {s}\n", .{op});
        }
    }
}

pub fn process(tui: *Tui) !void {
    try tui.read();
    switch (tui.r_buf[0]) {
        'k' => sel = @max(sel -| 1, 0),
        'j' => sel = @min(sel + 1, 2),
        'q' => tui.flags.should_quit = true,
        else => return,
    }
}

// const help_bar = "j,k: up,down · /:search · q: quit · ?:help";
