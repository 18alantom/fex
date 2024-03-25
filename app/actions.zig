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
        state.reiterate = true; // TODO: is this required?
    } else {
        state.reiterate = try toggleItemChildren(item);
    }

    if (!state.reiterate) {
        return;
    }

    state.view.cursor += 1;
}

pub fn toggleChildren(state: *State) !void {
    const item = state.itemUnderCursor();
    state.reiterate = try toggleItemChildren(item);
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
