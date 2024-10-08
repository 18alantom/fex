/// The main struct, App.run is used to run *fex*
const std = @import("std");
const args = @import("./args.zig");
const tui = @import("../tui.zig");
const utils = @import("../utils.zig");

const State = @import("./State.zig");
const Manager = @import("../fs/Manager.zig");
const Item = @import("../fs/Item.zig");
const View = @import("./View.zig");
const Viewport = @import("./Viewport.zig");
const TreeView = @import("./TreeView.zig");
const Input = @import("./Input.zig");
const Output = @import("./Output.zig");
const Stat = @import("../fs/Stat.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const bS = tui.style.style;
const terminal = tui.terminal;

const ItemError = Item.ItemError;
const TimeType = Stat.TimeType;

const log = std.log.scoped(.app);

allocator: mem.Allocator,
state: *State,

const Self = @This();

pub const Config = struct {
    root: []const u8,
    // Display config
    icons: bool = true,
    size: bool = true,
    perm: bool = true,
    time: bool = true,
    link: bool = true,
    time_type: TimeType = .modified,
    user: bool = false,
    group: bool = false,
    dotfiles: bool = false,

    // Search config
    fuzzy_search: bool = true,
    ignore_case: bool = true,

    // Viewport config
    fullscreen: bool = false,
};

pub fn init(allocator: mem.Allocator, config: *Config) !Self {
    const state = try allocator.create(State);
    state.* = try State.init(allocator, config);

    return .{
        .allocator = allocator,
        .state = state,
    };
}

pub fn deinit(self: *Self) void {
    self.state.deinit();
    self.allocator.destroy(self.state);
}

pub fn run(self: *Self) !void {
    try self.state.preRun();
    defer self.state.postRun() catch {};

    while (true) {
        try self.state.updateViewport();
        try self.state.fillBuffer();
        try self.state.updateView();
        try self.state.printContents();

        const action = try self.state.getAppAction();

        switch (action) {
            .quit => break,
            .no_action => continue,
            else => try self.state.executeAction(action),
        }

        if (self.state.stdout.items.len > 0) {
            break;
        }
    }
}
