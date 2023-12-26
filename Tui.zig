const std = @import("std");
const terminal = @import("terminal.zig");

const fs = std.fs;
const os = std.os;
const io = std.io;
const fmt = std.fmt;
const mem = std.mem;

const Self = @This();
pub const Flags = struct {
    should_quit: bool = false,
};
pub const Config = struct {
    process: *const fn (tui: *Self) anyerror!void,
    render: *const fn (tui: *Self) anyerror!void,
};

reader: fs.File.Reader, // stdin
writer: fs.File.Writer, // stdout
allocator: mem.Allocator,
flags: Flags,
r_buf: []u8, // read buffer
// w_buf: []u8, // write buffer
r_len: usize = 0,
config: Config,

pub fn init(allocator: mem.Allocator, config: Config) !Self {
    return .{
        .reader = std.io.getStdIn().reader(),
        .writer = std.io.getStdOut().writer(),
        .allocator = allocator,
        .flags = Flags{},
        .r_buf = try allocator.alloc(u8, 1024),
        // .w_buf = try allocator.alloc(u8, 1024),
        .config = config,
    };
}

fn deinit(self: *Self) void {
    self.allocator.free(self.r_buf);
    // self.allocator.free(self.w_buf);
}

pub fn loop(self: *Self) !void {
    try terminal.enableRawMode();
    defer terminal.disableRawMode();

    defer self.deinit();

    while (true) {
        try self.config.render(self);
        try self.config.process(self);

        if (self.flags.should_quit) {
            break;
        }
    }
}

pub fn write(self: *Self, str: []const u8) !void {
    try self.writer.writeAll(str);
}

pub fn read(self: *Self) !void {
    self.r_len = try self.reader.read(self.r_buf);
}
