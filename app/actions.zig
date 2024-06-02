const builtin = @import("builtin");

const std = @import("std");
const utils = @import("../utils.zig");
const apputils = @import("./utils.zig");

const State = @import("./State.zig");
const Item = @import("../fs/Item.zig");

const ascii = std.ascii;
const log = std.log.scoped(.actions);

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
    const item = state.getItemUnderCursor();
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
    const item = state.getItemUnderCursor();
    if (item.hasChildren()) {
        state.reiterate = true;
    } else {
        state.reiterate = try apputils.toggleItemChildren(item);
    }

    if (!state.reiterate) {
        return;
    }

    state.view.cursor += 1;
}

pub fn toggleChildrenOrOpenFile(state: *State) !void {
    const item = state.getItemUnderCursor();
    if (try item.isDir()) {
        state.reiterate = try apputils.toggleItemChildren(item);
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
    var new_root = state.getItemUnderCursor();
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
    const entry = state.getEntryUnderCursor();
    const item = entry.item;
    const initial = state.view.cursor;

    var i: usize = (state.getItemIndex(item) catch return) -| 1;
    while (i > 0) : (i = i - 1) {
        const possible_sibling = state.view.buffer.items[i];
        state.view.cursor = i;

        if (possible_sibling.depth != entry.depth) {
            break;
        }
    }

    if (state.view.cursor != initial) {
        return;
    }

    state.view.cursor = initial -| 1;
}

pub fn toNextFold(state: *State) !void {
    const entry = state.getEntryUnderCursor();
    const item = entry.item;
    const initial = state.view.cursor;

    var i: usize = (state.getItemIndex(item) catch return) + 1;
    while (i < state.view.buffer.items.len) : (i = i + 1) {
        state.view.cursor = i;
        const possible_sibling = state.view.buffer.items[i];
        if (possible_sibling.depth != entry.depth) {
            break;
        }

        if (i == (state.view.buffer.items.len - 1) and !(try state.appendOne())) {
            break;
        }
    }

    if (state.view.cursor != initial or state.view.buffer.items.len > initial + 1) {
        return;
    }

    state.view.cursor = initial + 1;
}

pub fn openItem(state: *State) !void {
    const item = state.getItemUnderCursor();
    try utils.os.open(item.abspath());
}

pub fn toggleInfo(state: *State) void {
    state.output.treeview.info.show = !state.output.treeview.info.show;
    state.view.print_all = true;
}

pub fn changeDir(state: *State) !void {
    // Handled by shell line editing widget
    const item = state.getItemUnderCursor();
    if (!(try item.isDir())) {
        return;
    }

    try state.stdout.appendSlice("cd\n");
    try state.stdout.appendSlice(item.abspath());
    try state.stdout.appendSlice("\n");
}

pub fn search(state: *State) void {
    state.pre_search_cursor = state.view.cursor;
    state.input.search.start();
}

pub fn execSearch(state: *State) !void {
    // Updates cursor w.r.t search query.
    var index: usize = 0;
    while (true) {
        defer index += 1;

        if (!(try state.appendUntil(index + 1))) {
            return;
        }

        if (!apputils.isMatch(state, index)) {
            continue;
        }

        state.view.cursor = index;
        return;
    }
}

pub fn acceptSearch(state: *State) !void {
    state.view.print_all = true;
}

pub fn dismissSearch(state: *State) void {
    state.view.cursor = state.pre_search_cursor;
    state.view.print_all = true;
}

pub fn command(state: *State) void {
    state.input.command.start();
}

pub fn execCommand(state: *State) !void {
    // Handled by shell line editing widget
    for (state.input.command.string()) |c| {
        const char = if (ascii.isWhitespace(c)) '\n' else c;
        try state.stdout.append(char);
    }

    try state.stdout.appendSlice("\n");
    const item = state.getItemUnderCursor();
    try state.stdout.appendSlice(item.abspath());
    try state.stdout.appendSlice("\n");
    log.info("execCommand: \"{s}\"", .{state.input.command.string()});
}

pub fn dismissCommand(state: *State) void {
    state.view.print_all = true;
}

pub fn toggleSelection(state: *State) void {
    var entry = state.getEntryUnderCursor();
    entry.selected = !entry.selected;
    log.debug("toggleSelection: selected={any}, {s}", .{ entry.selected, entry.item.name() });
}
