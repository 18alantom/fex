pub const terminal = @import("tui/terminal.zig");
pub const style = @import("tui/style.zig");
pub const Draw = @import("tui/Draw.zig");
pub const buffered_stdout = @import("tui/buffered_stdout.zig");

pub const _BufferedStdOut = buffered_stdout.BufferedStdOut;
// FIXME: Should be dynamic?
pub const BufferedStdOut = _BufferedStdOut(262_144);
