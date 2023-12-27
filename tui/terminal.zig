const std = @import("std");

const os = std.os;

pub const Size = struct {
    cols: u16,
    rows: u16,
};

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
pub fn disableRawMode() !void {
    var termios = try os.tcgetattr(os.STDIN_FILENO);
    termios.lflag &= (os.system.ECHO | os.system.ICANON);
    try os.tcsetattr(
        os.STDIN_FILENO,
        os.TCSA.FLUSH,
        termios,
    );
}
