const std = @import("std");

const os = std.os;
const fmt = std.fmt;

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
    var ws: os.system.winsize = undefined;
    _ = os.system.ioctl(os.STDOUT_FILENO, os.system.T.IOCGWINSZ, &ws);
    return .{ .cols = ws.ws_col, .rows = ws.ws_row };
}

pub fn getCursorPosition() !Position {
    // Needs Raw mode (no wait for \n) to work properly cause
    // control sequence will not be written without it.
    //
    // TODO: probably needs some kind of mutex?
    _ = try os.write(os.STDOUT_FILENO, "\x1b[6n");

    var buf: [64]u8 = undefined;

    // format: \x1b, "[", R1,..., Rn, ";", C1, ..., Cn, "R"
    var len = try os.read(os.STDIN_FILENO, &buf);

    if (len < 6 or buf[0] != 27 or buf[1] != '[') {
        return error.InvalidValueReturned;
    }

    var row: [8]u8 = undefined;
    var col: [8]u8 = undefined;

    var ridx: u3 = 0;
    var cidx: u3 = 0;

    var is_parsing_cols = false;
    for (2..(len - 1)) |i| {
        var b = buf[i];
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
pub fn disableRawMode() !void {
    var termios = try os.tcgetattr(os.STDIN_FILENO);
    termios.lflag &= (os.system.ECHO | os.system.ICANON);
    try os.tcsetattr(
        os.STDIN_FILENO,
        os.TCSA.FLUSH,
        termios,
    );
}
