const std = @import("std");
const utils = @import("utils.zig");

const tui = @import("tui.zig");
const Draw = tui.Draw;
const terminal = tui.terminal;

const fs = std.fs;
const io = std.io;
const os = std.os;
const fmt = std.fmt;
const time = std.time;
const mem = std.mem;

const print = std.debug.print;
const bufStyle = tui.style.bufStyle;

allocator: mem.Allocator,

rbuf: []u8, // buffer for reading input
sbuf: []u8, // buffer for styling output
rlen: usize = 0, // num bytes read into rbuf

reader: fs.File.Reader,
writer: fs.File.Writer,

draw: Draw,

counter: usize = 0,

flags: Flags = .{},
size: terminal.Size = .{ .cols = 0, .rows = 0 },

const Self = @This();
const Flags = struct {
    should_quit: bool = false,
    render_chrome: bool = true,
};

pub fn init(allocator: mem.Allocator) !Self {
    var rbuf = try allocator.alloc(u8, 2048);
    var sbuf = try allocator.alloc(u8, 2048);

    var reader = io.getStdIn().reader();
    var writer = io.getStdIn().writer();

    const draw = Draw{ .writer = writer };
    return .{
        .allocator = allocator,
        .rbuf = rbuf,
        .sbuf = sbuf,
        .reader = reader,
        .writer = writer,
        .draw = draw,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.rbuf);
    self.allocator.free(self.sbuf);
}

pub fn run(self: *Self) !void {
    try terminal.enableRawMode();
    defer terminal.disableRawMode() catch {};

    try self.draw.hideCursor();
    defer self.draw.showCursor() catch {};

    while (true) {
        defer self.counter += 1;
        if (self.flags.should_quit) {
            break;
        }

        self.render() catch break;
        self.process() catch break;
    }
}

fn render(self: *Self) !void {
    self.size = terminal.getTerminalSize();

    if (self.flags.render_chrome) {
        try self.renderChrome();
    }

    var wbuf: [1024]u8 = undefined;
    const slc = try fmt.bufPrint(&wbuf, "counter: {d:5}", .{self.counter});

    try self.draw.string(slc, .{
        .col = 0,
        .row = 0,
        .style = try bufStyle(self.sbuf, .{ .inverse = true, .fg = .magenta }),
    });
}

fn renderChrome(self: *Self) !void {
    defer self.flags.render_chrome = false;
    for (0..self.size.rows) |r| {
        for (0..self.size.cols) |c| {
            var style = try bufStyle(self.sbuf, .{
                .fg = .blue,
            });
            try self.draw.string("\u{2588}", .{ .col = c, .row = r, .style = style });
        }
    }
}

fn process(self: *Self) !void {
    try self.read();
    if (self.rlen == 1 and self.rbuf[0] == 'q') {
        self.flags.should_quit = true;
    }
}

fn read(self: *Self) !void {
    self.rlen = try self.reader.read(self.rbuf);
}
