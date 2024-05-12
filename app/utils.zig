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

    if (query.len > candidate.len) return false;

    var match: bool = false;
    if (state.fuzzy_search) {
        match = string.fuzzySearch(query, candidate, state.ignore_case);
    } else {
        match = string.search(query, candidate, state.ignore_case);
    }

    log.debug("isMatch: {any}, query: {s}, candidate: {s}", .{ match, query, candidate });
    return match;
}

pub fn toggleItemChildren(item: *Item) !bool {
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
