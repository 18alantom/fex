const std = @import("std");

const posix = std.posix;
const fmt = std.fmt;
const log = std.log.scoped(.terminal);

pub const Size = struct {
    cols: u16,
    rows: u16,
};

pub const Position = struct {
    col: u16,
    row: u16,
};

/// Gets number of rows and columns in the terminal
pub fn getTerminalSize() Size {
    var ws: posix.winsize = undefined;
    _ = posix.system.ioctl(posix.STDERR_FILENO, posix.T.IOCGWINSZ, &ws);
    return .{ .cols = ws.ws_col, .rows = ws.ws_row };
}

pub fn getCursorPosition() !Position {
    // Needs Raw mode (no wait for \n) to work properly cause
    // control sequence will not be written without it.
    _ = try posix.write(posix.STDERR_FILENO, "\x1b[6n");

    var buf: [64]u8 = undefined;

    // format: \x1b, "[", R1,..., Rn, ";", C1, ..., Cn, "R"
    const len = try posix.read(posix.STDIN_FILENO, &buf);

    if (len < 6 or buf[0] != 27 or buf[1] != '[') {
        return error.InvalidValueReturned;
    }

    var row: [8]u8 = undefined;
    var col: [8]u8 = undefined;

    var ridx: u3 = 0;
    var cidx: u3 = 0;

    var is_parsing_cols = false;
    for (2..(len - 1)) |i| {
        const b = buf[i];
        if (b == ';') {
            is_parsing_cols = true;
            continue;
        }

        if (b == 'R') {
            break;
        }

        if (is_parsing_cols) {
            col[cidx] = buf[i];
            cidx += 1;
        } else {
            row[ridx] = buf[i];
            ridx += 1;
        }
    }

    return .{
        .row = try fmt.parseInt(u16, row[0..ridx], 10),
        .col = try fmt.parseInt(u16, col[0..cidx], 10),
    };
}

/// Sets the following
/// - ~IXON: disables start/stop output flow (reads CTRL-S, CTRL-Q)
/// - ~ICRNL: disables CR to NL translation (reads CTRL-M)
/// - ~IEXTEN: disable implementation defined functions (reads CTRL-V, CTRL-O)
/// - ~ECHO: user input is not printed to terminal
/// - ~ICANON: read runs for every input (no waiting for `\n`)
/// - ISIG: enable QUIT, ISIG, SUSP.
///
/// `bak`: pointer to store termios struct backup before
/// altering, this is used to disable raw mode.
pub fn enableRawMode(bak: *posix.termios) !void {
    var termios = try posix.tcgetattr(posix.STDIN_FILENO);
    bak.* = termios;

    termios.iflag.IXON = false;
    termios.iflag.ICRNL = false;

    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.lflag.IEXTEN = false;
    termios.lflag.ISIG = true;

    // termios.iflag &= ~(posix.system.IXON | posix.system.ICRNL);
    // termios.lflag &= ~(posix.system.ECHO | posix.system.ICANON | posix.system.IEXTEN) | posix.system.ISIG;
    try posix.tcsetattr(
        posix.STDIN_FILENO,
        posix.TCSA.FLUSH,
        termios,
    );
}

/// Reverts `enableRawMode` to restore initial functionality.
pub fn disableRawMode(bak: *posix.termios) !void {
    try posix.tcsetattr(
        posix.STDIN_FILENO,
        posix.TCSA.FLUSH,
        bak.*,
    );
    return;
}
