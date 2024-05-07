const std = @import("std");

const fs = std.fs;
const mem = std.mem;
const os = std.os;

const Manager = @import("../fs/Manager.zig");
const Item = @import("../fs/Item.zig");
const View = @import("./View.zig");
const Viewport = @import("./Viewport.zig");
const TreeView = @import("./TreeView.zig");
const Input = @import("./Input.zig");
const Output = @import("./Output.zig");
const App = @import("./App.zig");
const Capture = @import("./Capture.zig");

const actions = @import("./actions.zig");
const utils = @import("../utils.zig");
const args = @import("./args.zig");

const CharArray = utils.CharArray;
const AppAction = Input.AppAction;
const Config = App.Config;

const log = std.log.scoped(.state);

viewport: *Viewport,
view: *View,
output: *Output,
input: *Input,
manager: *Manager,
search: *Capture,

// If `stdout` is not empty, screen is cleared (stderr)
// and contents of `stdout` are written to stdout and
// fex exits.
//
// This is used to set prompt to a command.
stdout: *CharArray,

reiterate: bool,
itermode: i32,
iterator: ?*Manager.Iterator,

allocator: mem.Allocator,

const Self = @This();

pub fn init(allocator: mem.Allocator, config: *Config) !Self {
    const viewport = try allocator.create(Viewport);
    viewport.* = try Viewport.init();

    const view = try allocator.create(View);
    view.* = View.init(allocator);

    const output = try allocator.create(Output);
    output.* = try Output.init(allocator, config);

    const input = try allocator.create(Input);
    input.* = Input.init();

    const manager = try allocator.create(Manager);
    manager.* = try Manager.init(allocator, config.root);

    const stdout = try allocator.create(CharArray);
    stdout.* = CharArray.init(allocator);

    const search = try allocator.create(Capture);
    search.* = try Capture.init(allocator);

    return .{
        .viewport = viewport,
        .view = view,
        .output = output,
        .input = input,
        .manager = manager,
        .stdout = stdout,
        .search = search,

        .reiterate = false,
        .itermode = -2,
        .iterator = null,

        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.viewport.deinit();
    self.allocator.destroy(self.viewport);

    self.view.deinit();
    self.allocator.destroy(self.view);

    self.output.deinit();
    self.allocator.destroy(self.output);

    self.input.deinit();
    self.allocator.destroy(self.input);

    self.stdout.deinit();
    self.allocator.destroy(self.stdout);

    self.search.deinit();
    self.allocator.destroy(self.search);

    if (self.iterator) |iter| {
        iter.deinit();
        self.allocator.destroy(iter);
    }

    self.manager.deinit();
    self.allocator.destroy(self.manager);
}

pub fn preRun(self: *Self) !void {
    try self.viewport.setBounds();
    _ = try self.manager.root.children();
    self.reiterate = true;
}

pub fn fillBuffer(self: *Self) !void {
    if (!self.reiterate) {
        return;
    }

    defer self.reiterate = false;
    try self.initializeIterator();

    const max_append = self.view.first + self.viewport.max_rows;
    self.view.buffer.clearAndFree();

    while (self.iterator.?.next()) |e| {
        try self.view.buffer.append(e);
        if (self.view.buffer.items.len >= max_append) {
            break;
        }
    }
    self.itermode = -2;
    self.view.print_all = true;
}

fn initializeIterator(self: *Self) !void {
    if (self.iterator) |iter| {
        iter.deinit();
        self.allocator.destroy(iter);
    }

    const iterator = try self.allocator.create(Manager.Iterator);
    iterator.* = try self.manager.iterate(self.itermode);

    self.iterator = iterator;
}

pub fn updateView(self: *Self) !void {
    try self.view.update(
        self.iterator.?,
        self.viewport.max_rows,
    );
}

pub fn printContents(self: *Self) !void {
    try self.output.printContents(
        self.viewport.start_row,
        self.view,
    );
}

pub fn waitForAction(self: *Self) !Input.AppAction {
    if (self.search.is_capturing) {
        try self.captureSearchQuery();
        return .no_action;
    }

    return try self.input.getAppAction();
}

fn captureSearchQuery(self: *Self) !void {
    var buf: [256]u8 = undefined;
    const slc = self.input.read(&buf) catch |err| switch (err) {
        error.EndOfStream => return,
        else => return err,
    };

    if (slc.len == 1 and slc[0] == 27) {
        self.search.stop();
        return;
    }

    try self.search.capture(slc);
    log.debug("search_query: \"{s}\"", .{self.search.string()});
}

pub fn executeAction(self: *Self, action: AppAction) !void {
    self.view.prev_cursor = self.view.cursor;
    switch (action) {
        .up => actions.moveCursorUp(self),
        .down => actions.moveCursorDown(self),
        .top => actions.goToTop(self),
        .bottom => try actions.goToBottom(self),
        .left => try actions.shiftIntoParent(self),
        .right => try actions.shiftIntoChild(self),
        .select => try actions.toggleChildrenOrOpenFile(self),
        .expand_all => actions.expandAll(self),
        .collapse_all => actions.collapseAll(self),
        .prev_fold => actions.toPrevFold(self),
        .next_fold => try actions.toNextFold(self),
        .change_root => try actions.changeRoot(self),
        .open_item => try actions.openItem(self),
        .change_dir => try actions.changeDir(self),
        .depth_one => actions.expandToDepth(self, 0),
        .depth_two => actions.expandToDepth(self, 1),
        .depth_three => actions.expandToDepth(self, 2),
        .depth_four => actions.expandToDepth(self, 3),
        .depth_five => actions.expandToDepth(self, 4),
        .depth_six => actions.expandToDepth(self, 5),
        .depth_seven => actions.expandToDepth(self, 6),
        .depth_eight => actions.expandToDepth(self, 7),
        .depth_nine => actions.expandToDepth(self, 8),
        .toggle_info => actions.toggleInfo(self),
        .search => actions.search(self),
        .no_action => return,
        .quit => return error.QuitApp,
    }
}

pub fn entryUnderCursor(self: *Self) *Manager.Iterator.Entry {
    return &self.view.buffer.items[self.view.cursor];
}

pub fn itemUnderCursor(self: *Self) *Item {
    return self.entryUnderCursor().item;
}

pub fn getItemIndex(self: *Self, item: *Item) !usize {
    for (0..self.view.buffer.items.len) |i| {
        if (self.view.buffer.items[i].item != item) {
            continue;
        }

        return i;
    }

    return error.NotFound;
}

pub fn appendOne(self: *Self) !bool {
    if (self.iterator == null) {
        return false;
    }

    const entry = self.iterator.?.next();
    if (entry == null) {
        return false;
    }

    try self.view.buffer.append(entry.?);
    return true;
}

pub fn dumpStdout(self: *Self) !bool {
    if (self.stdout.items.len == 0) return false;
    self.output.writer.unbuffered();
    try self.output.draw.clearLinesBelow(self.viewport.start_row);

    _ = try std.io.getStdOut().writer().write(self.stdout.items);
    return true;
}
