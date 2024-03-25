const std = @import("std");
const tui = @import("../tui.zig");
const View = @import("./View.zig");
const TreeView = @import("./TreeView.zig");

const fs = std.fs;
const mem = std.mem;
const io = std.io;

// Self
draw: tui.Draw,
writer: fs.File.Writer,

treeview: TreeView,
obuf: [2048]u8, // Content Buffer
sbuf: [2048]u8, // Style Buffer

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    const writer = io.getStdOut().writer();
    const draw = tui.Draw{ .writer = writer };
    var treeview = TreeView.init(allocator);

    try draw.hideCursor();
    return .{
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
}

pub fn printContents(self: *Self, start_row: u16, view: View) !void {
    try self.draw.moveCursor(start_row, 0);
    try self.treeview.printLines(
        &view,
        self.draw,
    );
}
