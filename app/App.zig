/// The main struct, App.run is used to run *fex*
const std = @import("std");
const tui = @import("../tui.zig");
const utils = @import("../utils.zig");

const Manager = @import("../fs/Manager.zig");
const Item = @import("../fs/Item.zig");
const View = @import("./View.zig");
const Viewport = @import("./Viewport.zig");
const TreeView = @import("./TreeView.zig");
const Input = @import("./Input.zig");
const Output = @import("./Output.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const bS = tui.style.bufStyle;
const terminal = tui.terminal;

const ItemError = Item.ItemError;

allocator: mem.Allocator,
manager: *Manager,

const State = {};

const Self = @This();

pub fn init(allocator: mem.Allocator, root: []const u8) !Self {
    return .{
        .allocator = allocator,
        .manager = try Manager.init(allocator, root),
    };
}

pub fn deinit(self: *Self) void {
    self.manager.deinit();
}

const Entry = Manager.Iterator.Entry;
pub fn run(self: *Self) !void {
    var vp = try Viewport.init();
    defer vp.deinit();

    try vp.setBounds();

    _ = try self.manager.root.children();

    // Buffer iterated elements to allow backtracking
    var view = View.init(self.allocator);
    defer view.deinit();

    var out = try Output.init(self.allocator);
    defer out.deinit();

    var inp = Input.init();
    defer inp.deinit();

    // Iterates over fs tree
    var reiterate = true;
    var iter_or_null: ?Manager.Iterator = null;
    defer {
        if (iter_or_null != null) iter_or_null.?.deinit();
    }

    var iter_mode: i32 = -2;
    while (true) {
        if (reiterate) {
            defer reiterate = false;
            if (iter_or_null != null) iter_or_null.?.deinit();

            iter_or_null = try self.manager.iterate(iter_mode);

            var max_append = view.first + vp.max_rows;
            view.buffer.clearAndFree();
            while (iter_or_null.?.next()) |e| {
                if (view.buffer.items.len > max_append) break;
                try view.buffer.append(e);
            }
            iter_mode = -2;
        }

        try view.update(
            &iter_or_null.?,
            vp.max_rows,
        );

        // Print contents of view buffer in range
        try out.printContents(vp.start_row, view);

        const app_action = try inp.getAppAction();
        switch (app_action) {
            .down => view.cursor += 1,
            .up => view.cursor -|= 1,
            .top => view.cursor = 0,
            .left => if (view.buffer.items[view.cursor].item._parent) |parent| {
                for (0..view.buffer.items.len) |i| {
                    if (view.buffer.items[i].item != parent) continue;
                    view.cursor = i;
                    break;
                }
            } else if (try self.manager.up()) |_| {
                view.cursor = 0;
                reiterate = true;
            } else {
                continue;
            },
            .right => {
                const item = view.buffer.items[view.cursor].item;
                if (item.hasChildren()) {
                    reiterate = true;
                } else {
                    reiterate = try toggleChildren(item);
                }
                if (reiterate) view.cursor += 1;
            },
            .bottom => {
                while (iter_or_null.?.next()) |e| try view.buffer.append(e);
                view.cursor = view.buffer.items.len - 1;
            },
            .select => {
                const item = view.buffer.items[view.cursor].item;
                reiterate = try toggleChildren(item);
            },
            .expand_all => {
                iter_mode = -1;
                reiterate = true;
            },
            .collapse_all => {
                self.manager.root.freeChildren(null);
                view.cursor = 0;
                reiterate = true;
            },
            .depth_one => {
                iter_mode = 0;
                reiterate = true;
            },
            .depth_two => {
                iter_mode = 1;
                reiterate = true;
            },
            .depth_three => {
                iter_mode = 2;
                reiterate = true;
            },
            .depth_four => {
                iter_mode = 3;
                reiterate = true;
            },
            .depth_five => {
                iter_mode = 4;
                reiterate = true;
            },
            .depth_six => {
                iter_mode = 5;
                reiterate = true;
            },
            .depth_seven => {
                iter_mode = 6;
                reiterate = true;
            },
            .depth_eight => {
                iter_mode = 7;
                reiterate = true;
            },
            .depth_nine => {
                iter_mode = 8;
                reiterate = true;
            },
            .quit => return,
        }

        try out.draw.clearLinesBelow(vp.start_row);
    }
}

fn appendAll() void {}

fn toggleChildren(item: *Item) !bool {
    if (item.hasChildren()) {
        item.freeChildren(null);
        return true;
    }

    _ = item.children() catch |e| {
        switch (e) {
            ItemError.IsNotDirectory => return false,
            else => return e,
        }
    };
    return true;
}
