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

const terminal = @import("../tui/terminal.zig");
const actions = @import("./actions.zig");
const utils = @import("../utils.zig");
const args = @import("./args.zig");

const CharArray = utils.CharArray;
const SearchQuery = utils.string.SearchQuery;
const AppAction = Input.AppAction;
const Config = App.Config;

const log = std.log.scoped(.state);

viewport: *Viewport,
view: *View,
output: *Output,
input: *Input,
manager: *Manager,

// If `stdout` is not empty, screen is cleared (stderr)
// and contents of `stdout` are written to stdout and
// fex exits.
//
// This is used to set prompt to a command.
stdout: *CharArray,

reiterate: bool,
itermode: i32,
iterator: ?*Manager.Iterator,
dotfiles: bool,

// Search config
pre_search_cursor: usize,
fuzzy_search: bool,
ignore_case: bool,

// Viewport config
fullscreen: bool,

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
    input.* = try Input.init(allocator);

    const manager = try allocator.create(Manager);
    manager.* = try Manager.init(allocator, config.root);

    const stdout = try allocator.create(CharArray);
    stdout.* = CharArray.init(allocator);

    return .{
        .viewport = viewport,
        .view = view,
        .output = output,
        .input = input,
        .manager = manager,
        .stdout = stdout,

        .reiterate = false,
        .itermode = -2,
        .iterator = null,
        .dotfiles = config.dotfiles,

        .pre_search_cursor = 0,
        .fuzzy_search = config.fuzzy_search,
        .ignore_case = config.ignore_case,

        .fullscreen = config.fullscreen,

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

    if (self.iterator) |iter| {
        iter.deinit();
        self.allocator.destroy(iter);
    }

    self.manager.deinit();
    self.allocator.destroy(self.manager);
}

pub fn preRun(self: *Self) !void {
    if (self.fullscreen) {
        self.output.writer.unbuffered();
        try self.output.draw.enableAlternateBuffer();
        try self.output.draw.clearScreen();
    }

    try self.viewport.initBounds();
    _ = try self.manager.root.children();
    self.reiterate = true;
}

pub fn postRun(self: *Self) !void {
    if (self.fullscreen) {
        try self.output.draw.disableAlternateBuffer();
    }

    if (self.stdout.items.len > 0) {
        try self.dumpStdout();
    }
}

pub fn updateViewport(self: *Self) !void {
    const bounds_updated = try self.viewport.updateBounds();
    self.view.print_all = bounds_updated or self.view.print_all;
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
    iterator.* = try self.manager.iterate(self.itermode, self.dotfiles);

    self.iterator = iterator;
}

pub fn updateView(self: *Self) !void {
    try self.view.update(
        self.iterator.?,
        self.viewport.max_rows,
    );
}

pub fn printContents(self: *Self) !void {
    var search_query: ?*const SearchQuery = null;
    if (self.input.search.is_capturing) {
        search_query = &.{
            .fuzzy_search = self.fuzzy_search,
            .ignore_case = self.ignore_case,
            .query = self.input.search.string(),
        };
    }

    try self.output.printContents(
        self.viewport.start_row,
        self.view,
        search_query,
        self.input.command.is_capturing,
    );

    if (self.input.search.is_capturing) {
        try self.output.printCaptureString(self.view, self.viewport, self.input.search);
    } else if (self.input.command.is_capturing) {
        try self.output.printCaptureString(self.view, self.viewport, self.input.command);
    }
}

pub fn getAppAction(self: *Self) !Input.AppAction {
    return try self.input.getAppAction();
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

        .enter => try actions.toggleChildrenOrOpenFile(self),
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
        .toggle_icons => actions.toggleIcons(self),
        .toggle_size => actions.toggleSize(self),
        .toggle_perm => actions.togglePerm(self),
        .toggle_time => actions.toggleTime(self),
        .toggle_link => actions.toggleLink(self),
        .toggle_user => actions.toggleUser(self),
        .toggle_group => actions.toggleGroup(self),
        .toggle_dotfiles => actions.toggleDotfiles(self),

        .time_modified => actions.timeModified(self),
        .time_changed => actions.timeChanged(self),
        .time_accessed => actions.timeAccessed(self),

        .sort_name => actions.sort(self, .name, true),
        .sort_size => actions.sort(self, .size, true),
        .sort_time => actions.sortTime(self, true),

        .sort_name_desc => actions.sort(self, .name, false),
        .sort_size_desc => actions.sort(self, .size, false),
        .sort_time_desc => actions.sortTime(self, false),

        .search => actions.search(self),
        .update_search => try actions.execSearch(self),
        .accept_search => try actions.acceptSearch(self),
        .dismiss_search => actions.dismissSearch(self),

        .command => actions.command(self),
        .exec_command => try actions.execCommand(self),
        .dismiss_command => actions.dismissCommand(self),
        .select => actions.toggleSelection(self),

        // no-op, handled by the caller
        .quit => unreachable,
        .no_action => unreachable,
    }
}

pub fn getEntry(self: *Self, index: usize) ?*Manager.Iterator.Entry {
    if (self.view.buffer.items.len <= index) return null;

    return self.view.buffer.items[index];
}

pub fn getEntryUnderCursor(self: *Self) *Manager.Iterator.Entry {
    return self.view.buffer.items[self.view.cursor];
}

pub fn getItem(self: *Self, index: usize) ?*Item {
    if (self.getEntry(index)) |entry| {
        return entry.item;
    }

    return null;
}

pub fn getItemUnderCursor(self: *Self) *Item {
    return self.getEntryUnderCursor().item;
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

pub fn appendUntil(self: *Self, new_len: usize) !bool {
    while (true) {
        if (self.view.buffer.items.len >= new_len) {
            break;
        }

        if (!try self.appendOne()) {
            return false;
        }
    }

    return self.view.buffer.items.len >= new_len;
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

pub fn dumpStdout(self: *Self) !void {
    self.output.writer.unbuffered();
    try self.output.draw.clearLinesBelow(self.viewport.start_row);

    _ = try std.io.getStdOut().writer().write(self.stdout.items);
}
