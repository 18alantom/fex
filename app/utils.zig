const std = @import("std");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const ascii = std.ascii;

const State = @import("./State.zig");
const Item = @import("../fs/Item.zig");
const string = @import("../utils/string.zig");

const ItemError = Item.ItemError;
const log = std.log.scoped(.apputils);

pub fn isMatch(state: *State, index: usize) bool {
    const item_or_null = state.getItem(index);
    if (item_or_null == null) return false;

    const query = state.input.search.string();
    const candidate = item_or_null.?.name();

    const search_query: string.SearchQuery = .{
        .query = query,
        .ignore_case = state.ignore_case,
        .fuzzy_search = state.fuzzy_search,
    };

    return string.search(
        candidate,
        &search_query,
    );
}

pub fn toggleItemChildren(item: *Item) !bool {
    if (item.hasChildren()) {
        item.freeChildren(null);
        return true;
    }

    _ = item.children() catch |e| {
        // TODO: show user
        switch (e) {
            ItemError.IsNotDirectory => return false,
            error.AccessDenied => return false,
            else => return e,
        }
    };

    return true;
}
