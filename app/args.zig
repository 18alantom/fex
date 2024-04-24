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
            printHelp();
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

fn printHelp() void {
    std.debug.print("help to be written\n", .{});
}
