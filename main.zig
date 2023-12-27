const std = @import("std");
const utils = @import("utils.zig");
const App = @import("App.zig");

const tui = @import("tui.zig");
const Draw = tui.Draw;
const terminal = tui.terminal;

const fs = std.fs;
const io = std.io;
const os = std.os;
const fmt = std.fmt;
const time = std.time;
const mem = std.mem;
const heap = std.heap;

const print = std.debug.print;
const bufStyle = tui.style.bufStyle;

pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try App.init(allocator);
    defer app.deinit();

    app.run() catch {};
}
