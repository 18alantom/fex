/// Output is responsible for writing out values in View.buffer
/// to stdout. It uses TreeView—which handles formatting—to do so.
const std = @import("std");
const args = @import("./args.zig");
const tui = @import("../tui.zig");
const View = @import("./View.zig");
const App = @import("./App.zig");

const TreeView = @import("./TreeView.zig");
const Config = App.Config;

const fs = std.fs;
const mem = std.mem;
const io = std.io;

allocator: mem.Allocator,
draw: *tui.Draw,
writer: *tui.BufferedStdOut,

treeview: *TreeView,
obuf: [2048]u8, // Content Buffer
sbuf: [2048]u8, // Style Buffer

const Self = @This();

pub fn init(allocator: mem.Allocator, config: *Config) !Self {
    const treeview = try allocator.create(TreeView);
    const writer = try allocator.create(tui.BufferedStdOut);
    var draw = try allocator.create(tui.Draw);

    writer.* = tui.BufferedStdOut.init();
    draw.* = tui.Draw{ .writer = writer };
    treeview.* = TreeView.init(allocator, config);

    try draw.hideCursor();
    return .{
        .allocator = allocator,
        .writer = writer,
        .draw = draw,
        .treeview = treeview,
        .obuf = undefined,
        .sbuf = undefined,
    };
}

pub fn deinit(self: *Self) void {
    self.draw.showCursor() catch {};
    self.treeview.deinit();
    self.allocator.destroy(self.draw);
    self.allocator.destroy(self.treeview);
    self.allocator.destroy(self.writer);
}

pub fn printContents(self: *Self, start_row: u16, view: *View) !void {
    self.writer.buffered();
    defer {
        self.writer.flush() catch {};
        self.writer.unbuffered();
    }

    try self.draw.moveCursor(start_row, 0);
    try self.treeview.printLines(
        view,
        self.draw,
        start_row,
    );

    const rendered_rows: u16 = @intCast(view.last - view.first);
    try self.draw.clearLinesBelow(start_row + rendered_rows + 1);
}
