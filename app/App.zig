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
const Entry = Manager.Iterator.Entry;
const Config = args.Config;

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const bS = tui.style.style;
const terminal = tui.terminal;

const ItemError = Item.ItemError;

allocator: mem.Allocator,
state: *State,

const Self = @This();

pub fn init(allocator: mem.Allocator, config: *Config) !Self {
    var state = try allocator.create(State);
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
    while (true) {
        try self.state.fillBuffer();
        try self.state.updateView();
        try self.state.printContents();

        const action = try self.state.waitForAction();
        self.state.executeAction(action) catch |err| switch (err) {
            error.QuitApp => return,
            else => return err,
        };
    }
}
