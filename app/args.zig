const std = @import("std");
const utils = @import("../utils.zig");
const Stat = @import("../fs/Stat.zig");

const TimeType = Stat.TimeType;

const eql = utils.eql;

pub const Config = struct {
    no_icons: bool = false,
    no_size: bool = false,
    no_mode: bool = false,
    no_time: bool = false,
    time: TimeType = .modified,
    root: []const u8,
};

pub fn setConfig(config: *Config) !bool {
    var args_iter = std.process.args();
    if (!args_iter.skip()) {
        return false;
    }

    var argc: usize = 0;
    while (args_iter.next()) |arg| {
        if (argc == 0 and arg[0] != '-') {
            config.root = arg;
        } else if (eql(arg, "--no-icons")) {
            config.no_icons = true;
        } else if (eql(arg, "--no-size")) {
            config.no_size = true;
        } else if (eql(arg, "--no-mode")) {
            config.no_mode = true;
        } else if (eql(arg, "--no-time")) {
            config.no_time = true;
        } else if (eql(arg, "--time")) {
            config.time = getTime(args_iter.next());
        } else if (eql(arg, "--help")) {
            try printHelp();
            return true;
        }

        argc += 1;
    }

    return false;
}

fn getTime(arg: ?([:0]const u8)) TimeType {
    if (arg == null) return .modified;

    const a = arg.?;
    if (eql(a, "modified")) return .modified;
    if (eql(a, "changed")) return .changed;
    if (eql(a, "accessed")) return .accessed;

    return .modified;
}

fn getRoot() []const u8 {
    var args_iter = std.process.args();
    if (!args_iter.skip()) {
        return ".";
    }

    if (args_iter.next()) |r| {
        return r;
    }

    return ".";
}

const help =
    \\Usage
    \\  fex [path] [options]
    \\
    \\Example
    \\  fex ~/Desktop --time accessed
    \\
    \\Meta
    \\  --help              Print this help message
    \\
    \\Display Config
    \\  --no-icons          Skip printing icons
    \\  --no-size           Skip printing item sizes
    \\  --no-time           Skip printing all times
    \\  --no-mode           Skip printing permission info
    \\  --time VALUE        Set which time is displayed
    \\                      valid: modified, accessed, changed
    \\                      default: modified
    \\
    \\Navigation Controls
    \\  j, down_arrow       Cursor down
    \\  k, up_arrow         Cursor up
    \\  h, left_arrow       Up a dir
    \\  l, right_arrow      Down a dir
    \\  gg                  Jump to first item
    \\  G                   Jump to last item
    \\  {                   Jump to prev fold
    \\  }                   Jump to next fold
    \\  
    \\Action Controls
    \\  R                   Change root to item under cursor (if dir)
    \\  o                   Open item under cursor (only macOS)
    \\  I                   Toggle item stat info
    \\  E                   Expand all directories
    \\  C                   Collapse all directories
    \\  1..9                Expand all directories upto $NUM depth
    \\  q, ctrl-d           Quit
    \\
;

fn printHelp() !void {
    _ = try std.io.getStdOut().writer().write(help);
}
