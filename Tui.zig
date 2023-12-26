const std = @import("std");

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
pub const Size = struct {
    cols: u16,
    rows: u16,
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
    try enableRawMode();
    defer disableRawMode();

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

pub const border = struct {
    pub const reg = struct {
        pub const v = "\u{2502}"; // │
        pub const h = "\u{2500}"; // ─
        pub const tl = "\u{250C}"; // ┌
        pub const tr = "\u{2510}"; // ┐
        pub const bl = "\u{2514}"; // └
        pub const br = "\u{2518}"; // ┘
    };
};

pub const BorderType = enum {
    none,
    reg,
};

// pub const Content = union {
//     content: []u8,
//     component: Component,
// };

// pub const Component = struct {
//     content: Content,
//     config: Config,
// };

// pub const Config = struct {
//     width: f16 = 1.0,
//     height: f16 = 1.0,
//     padding: u8 = 0,
//     border: BorderType = .reg,
//     color: color.Color = .black,
//     bg_color: color.Color = .none,
//     border_color: color.Color = .none,
// };

/// Gets number of rows and columns in the terminal
pub fn getTerminalSize() Size {
    var ws: os.system.winsize = undefined;
    _ = os.system.ioctl(os.STDOUT_FILENO, os.system.T.IOCGWINSZ, &ws);
    return .{ .cols = ws.ws_col, .rows = ws.ws_row };
}

/// Sets the following
/// - ~ECHO: user input is not printed to terminal
/// - ~ICANON: read runs for every input (no waiting for `\n`)
pub fn enableRawMode() !void {
    var termios = try os.tcgetattr(os.STDIN_FILENO);
    termios.lflag &= ~(os.system.ECHO | os.system.ICANON);
    try os.tcsetattr(
        os.STDIN_FILENO,
        os.TCSA.FLUSH,
        termios,
    );
}

/// Reverts `enableRawMode` to restore initial functionality.
pub fn disableRawMode() void {
    var termios = os.tcgetattr(os.STDIN_FILENO) catch return;
    termios.lflag &= (os.system.ECHO | os.system.ICANON);
    os.tcsetattr(
        os.STDIN_FILENO,
        os.TCSA.FLUSH,
        termios,
    ) catch return;
}

/// Clear the screen and set cursor to the top left position.
pub fn clearScreen(self: *Self) !void {
    _ = try self.writer.write("\x1b[2J\x1b[H");
}

/// Clear N lines from the terminal screen off the bottom.
pub fn clearNLines(self: *Self, n: u16) !void {
    const size = getTerminalSize();
    var buf: [128]u8 = undefined;
    var slc = try fmt.bufPrint(&buf, "\x1b[{d}H\x1b[{d}A\x1b[0J", .{ size.rows, n });
    _ = try self.writer.write(slc);
}
