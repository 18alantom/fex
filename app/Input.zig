/// Input is responsible for converting values read from stdin
/// into AppAction values which are carried out by App.
const std = @import("std");
const tui = @import("../tui.zig");
const View = @import("./View.zig");
const TreeView = @import("./TreeView.zig");

const fs = std.fs;
const io = std.io;

const print = std.debug.print;

pub const AppAction = enum {
    up,
    down,
    left,
    right,
    select,
    quit,
    top,
    bottom,
    depth_one,
    depth_two,
    depth_three,
    depth_four,
    depth_five,
    depth_six,
    depth_seven,
    depth_eight,
    depth_nine,
    expand_all,
    collapse_all,
    prev_fold,
    next_fold,
    change_root,
    open_item,
    change_dir,
};

reader: fs.File.Reader,
rbuf: [2048]u8,
input: tui.Input,

const Self = @This();

pub fn init() Self {
    const reader = io.getStdIn().reader();
    var input = tui.Input{ .reader = reader };
    return .{
        .reader = reader,
        .input = input,
        .rbuf = undefined,
    };
}

pub fn deinit(_: *Self) void {}

pub fn getAppAction(self: *Self) !AppAction {
    while (true) {
        const key = try self.input.readKeys();
        return switch (key) {
            .enter => AppAction.select,
            // Navigation
            .up_arrow => AppAction.up,
            .k => AppAction.up,
            .down_arrow => AppAction.down,
            .j => AppAction.down,
            .left_arrow => AppAction.left,
            .h => AppAction.left,
            .right_arrow => AppAction.right,
            .l => AppAction.right,
            .gg => AppAction.top,
            .G => AppAction.bottom,
            .curly_open => AppAction.prev_fold,
            .curly_close => AppAction.next_fold,
            // External actions
            .o => AppAction.open_item,
            .cd => AppAction.change_dir,
            // Tree actions
            .R => AppAction.change_root,
            // Toggle fold
            .C => AppAction.collapse_all,
            .E => AppAction.expand_all,
            // Expand to depth
            .one => AppAction.depth_one,
            .two => AppAction.depth_two,
            .three => AppAction.depth_three,
            .four => AppAction.depth_four,
            .five => AppAction.depth_five,
            .six => AppAction.depth_six,
            .seven => AppAction.depth_seven,
            .eight => AppAction.depth_eight,
            .nine => AppAction.depth_nine,
            // Quit
            .q => AppAction.quit,
            .ctrl_c => AppAction.quit,
            .ctrl_d => AppAction.quit,
            else => continue,
        };
    }
}
