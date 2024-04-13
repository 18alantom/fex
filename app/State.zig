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
const actions = @import("./actions.zig");

const AppAction = Input.AppAction;

viewport: *Viewport,
view: *View,
output: *Output,
input: *Input,
manager: *Manager,

reiterate: bool,
itermode: i32,
iterator: ?*Manager.Iterator,

allocator: mem.Allocator,

const Self = @This();

pub fn init(allocator: mem.Allocator, root: []const u8) !Self {
    var viewport = try allocator.create(Viewport);
    viewport.* = try Viewport.init();

    var view = try allocator.create(View);
    view.* = View.init(allocator);

    var output = try allocator.create(Output);
    output.* = try Output.init(allocator);

    var input = try allocator.create(Input);
    input.* = Input.init();

    var manager = try allocator.create(Manager);
    manager.* = try Manager.init(allocator, root);

    return .{
        .viewport = viewport,
        .view = view,
        .output = output,
        .input = input,
        .manager = manager,

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

    var max_append = self.view.first + self.viewport.max_rows;
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

    var iterator = try self.allocator.create(Manager.Iterator);
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
        .select => try actions.toggleChildren(self),
        .expand_all => actions.expandAll(self),
        .collapse_all => actions.collapseAll(self),
        .prev_fold => actions.toPrevFold(self),
        .next_fold => try actions.toNextFold(self),
        .change_root => try actions.changeRoot(self),
        .open_item => try actions.openItem(self),
        .depth_one => actions.expandToDepth(self, 0),
        .depth_two => actions.expandToDepth(self, 1),
        .depth_three => actions.expandToDepth(self, 2),
        .depth_four => actions.expandToDepth(self, 3),
        .depth_five => actions.expandToDepth(self, 4),
        .depth_six => actions.expandToDepth(self, 5),
        .depth_seven => actions.expandToDepth(self, 6),
        .depth_eight => actions.expandToDepth(self, 7),
        .depth_nine => actions.expandToDepth(self, 8),
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

    var entry = self.iterator.?.next();
    if (entry == null) {
        return false;
    }

    try self.view.buffer.append(entry.?);
    return true;
}
