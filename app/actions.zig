const builtin = @import("builtin");

const std = @import("std");
const utils = @import("../utils.zig");
const State = @import("./State.zig");
const Item = @import("../fs/Item.zig");

const ItemError = Item.ItemError;

pub fn moveCursorUp(state: *State) void {
    state.view.cursor -|= 1;
}

pub fn moveCursorDown(state: *State) void {
    state.view.cursor += 1;
}

pub fn goToTop(state: *State) void {
    state.view.cursor = 0;
}

pub fn goToBottom(state: *State) !void {
    while (state.iterator.?.next()) |e| {
        try state.view.buffer.append(e);
    }

    state.view.cursor = state.view.buffer.items.len - 1;
}

pub fn shiftIntoParent(state: *State) !void {
    const item = state.itemUnderCursor();
    if (item._parent) |parent| {
        state.view.cursor = state.getItemIndex(parent) catch |err| switch (err) {
            error.NotFound => state.view.cursor,
            else => return err,
        };
    }

    // Cursor is at current root will have to expand parent.
    else if (try state.manager.up()) |_| {
        state.view.cursor = 0;
        state.reiterate = true;
    }
}

pub fn shiftIntoChild(state: *State) !void {
    const item = state.itemUnderCursor();
    if (item.hasChildren()) {
        state.reiterate = true;
    } else {
        state.reiterate = try toggleItemChildren(item);
    }

    if (!state.reiterate) {
        return;
    }

    state.view.cursor += 1;
}

pub fn toggleChildrenOrOpenFile(state: *State) !void {
    const item = state.itemUnderCursor();
    if (try item.isDir()) {
        state.reiterate = try toggleItemChildren(item);
        return;
    }

    try openItem(state);
}

pub fn expandAll(state: *State) void {
    state.itermode = -1;
    state.reiterate = true;
}

pub fn collapseAll(state: *State) void {
    state.manager.root.freeChildren(null);
    state.view.cursor = 0;
    state.reiterate = true;
}

pub fn expandToDepth(state: *State, itermode: i32) void {
    state.itermode = itermode;
    state.reiterate = true;
}

pub fn changeRoot(state: *State) !void {
    var new_root = state.itemUnderCursor();
    if (!try new_root.isDir()) {
        new_root = try new_root.parent();
    }

    if (new_root == state.manager.root) {
        return;
    }

    _ = try new_root.children();
    state.manager.changeRoot(new_root);
    state.view.cursor = 0;
    state.reiterate = true;
}

pub fn toPrevFold(state: *State) void {
    const entry = state.entryUnderCursor();
    const item = entry.item;
    var i: usize = (state.getItemIndex(item) catch return) -| 1;
    while (i > 0) : (i = i - 1) {
        const possible_sibling = state.view.buffer.items[i];
        if (possible_sibling.depth == entry.depth) {
            continue;
        }

        state.view.cursor = i;
        return;
    }

    state.view.cursor -|= 1;
}

pub fn toNextFold(state: *State) !void {
    const entry = state.entryUnderCursor();
    const item = entry.item;

    var i: usize = (state.getItemIndex(item) catch return) + 1;
    while (i < state.view.buffer.items.len) : (i = i + 1) {
        if (i == (state.view.buffer.items.len - 1)) {
            if (!(try state.appendOne())) break;
        }

        const possible_sibling = state.view.buffer.items[i];
        if (possible_sibling.depth == entry.depth) {
            continue;
        }

        state.view.cursor = i;
        return;
    }

    state.view.cursor +|= 1;
}

fn toggleItemChildren(item: *Item) !bool {
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

pub fn openItem(state: *State) !void {
    const item = state.itemUnderCursor();
    try utils.os.open(item.abspath());
}

pub fn toggleInfo(state: *State) void {
    state.output.treeview.info.show = !state.output.treeview.info.show;
    state.view.print_all = true;
}

pub fn changeDir(state: *State) !void {
    const item = state.itemUnderCursor();
    if (!(try item.isDir())) {
        return;
    }

    try state.stdout.appendSlice("cd\n");
    try state.stdout.appendSlice(item.abspath());
    try state.stdout.appendSlice("\n");
}
