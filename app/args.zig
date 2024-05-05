const std = @import("std");
const utils = @import("../utils.zig");
const Stat = @import("../fs/Stat.zig");
const App = @import("./App.zig");

const mem = std.mem;
const process = std.process;

const TimeType = Stat.TimeType;
const Config = App.Config;

const eql = utils.eql;

pub fn setConfigFromEnv(config: *Config) !void {
    const val_or_null = std.posix.getenv("FEX_DEFAULT_COMMAND");
    if (val_or_null == null) {
        return;
    }

    const SplitIterator = mem.SplitIterator(u8, .sequence);
    const iter: SplitIterator = utils.split(val_or_null.?, " ");
    _ = try ConfigIterator(SplitIterator).setConfig(
        config,
        iter,
        true,
    );
}

pub fn setConfig(config: *Config) !bool {
    var args_iter = process.args();
    if (!args_iter.skip()) {
        return false;
    }

    return try ConfigIterator(process.ArgIterator).setConfig(
        config,
        args_iter,
        false,
    );
}

fn ConfigIterator(Iterator: type) type {
    return struct {
        pub fn setConfig(config: *Config, iterator: Iterator, from_env: bool) !bool {
            var argc: usize = 0;
            var iterator_ = iterator;
            while (iterator_.next()) |arg| {
                defer argc += 1;

                if (argc == 0 and arg[0] != '-' and !from_env) {
                    config.root = arg;
                }

                // Display args
                else if (eql(arg, "--no-icons")) {
                    config.no_icons = true;
                } else if (eql(arg, "--no-size")) {
                    config.no_size = true;
                } else if (eql(arg, "--no-mode")) {
                    config.no_mode = true;
                } else if (eql(arg, "--no-time")) {
                    config.no_time = true;
                } else if (eql(arg, "--time")) {
                    config.time = getTime(iterator_.next());
                } else if (from_env) {
                    continue;
                }

                // Non-display args (run and quit)
                else if (eql(arg, "--setup-zsh")) {
                    try setupZsh();
                    return true;
                } else if (eql(arg, "--help")) {
                    try printHelp();
                    return true;
                }
            }

            return false;
        }
    };
}

fn getTime(arg: ?([]const u8)) TimeType {
    if (arg == null) return .modified;

    const a = arg.?;
    if (eql(a, "modified")) return .modified;
    if (eql(a, "changed")) return .changed;
    if (eql(a, "accessed")) return .accessed;

    return .modified;
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
    \\Setup
    \\  --setup-zsh         Setup fex ZSH widget and keybind it to CTRL-F
    \\
    \\Navigation Controls
    \\  j, down-arrow       Cursor down
    \\  k, up-arrow         Cursor up
    \\  h, left-arrow       Up a dir
    \\  l, right-arrow      Down a dir
    \\  gg                  Jump to first item
    \\  G                   Jump to last item
    \\  {                   Jump to prev fold
    \\  }                   Jump to next fold
    \\  
    \\Action Controls
    \\  return/enter        Toggle directory or open file (macOS)
    \\  o                   Open item under cursor (macOS)
    \\  E                   Expand all directories
    \\  C                   Collapse all directories
    \\  R                   Change root to item under cursor (if dir)
    \\  I                   Toggle item stat info
    \\  1..9                Expand all directories upto $NUM depth
    \\  q, ctrl-d           Quit
    \\
    \\File System Commands
    \\  cd                  Quit and change directory to item under cursor (needs setup)
    \\
;

fn printHelp() !void {
    _ = try std.io.getStdOut().writer().write(help);
}

fn setupZsh() !void {
    return error.NotImplemented;
}
