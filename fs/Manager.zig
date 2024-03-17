const std = @import("std");

const _item = @import("./item.zig");
const Item = _item.Item;
const ItemList = _item.ItemList;
const ItemError = _item.ItemError;

const fs = std.fs;
const mem = std.mem;
const os = std.os;

const print = std.debug.print;

const Self = @This();

root: *Item,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator, root: []const u8) !*Self {
    var m = try allocator.create(Self);

    m.root = try Item.init(allocator, root);
    m.allocator = allocator;

    return m;
}

pub fn deinit(self: *Self) void {
    self.root.deinit();
    self.allocator.destroy(self);
}

/// Sets root to current roots parent directory.
pub fn up(self: *Self) !?*Item {
    var new_root = self.root.parent() catch |err| {
        if (err == ItemError.NoParent) {
            return null;
        } else {
            return err;
        }
    };
    self.root = new_root;
    return self.root;
}

/// Sets root to child in the opened tree. Everything above
/// child (new_root) is freed.
///
/// Returns new_root if child is found in tree else null.
pub fn down(self: *Self, child: *Item) !?*Item {
    var _parent = try _findParent(self.root, child);
    if (_parent == null) {
        return null;
    }

    var parent = _parent.?;
    var is_root = parent == self.root;
    parent.deinitSkipChild(child);
    if (!is_root) {
        self.root.deinit();
    }

    self.root = child;
    return self.root;
}

pub fn findParent(self: *Self, child: *Item) !?*Item {
    return try _findParent(self.root, child);
}

fn _findParent(parent: *Item, child: *Item) !?*Item {
    if (!parent.hasChildren()) {
        return null;
    }

    const children = try parent.children();
    for (children.items) |ch| {
        if (ch == child) {
            return parent;
        }

        if (try _findParent(ch, child)) |p| {
            return p;
        }
    }

    return null;
}

pub fn iterate(self: *Self, depth: i32) !Iterator {
    return try Iterator.init(
        self.allocator,
        self.root,
        depth,
    );
}

pub const Iterator = struct {
    pub const Entry = struct {
        item: *Item,
        depth: usize,
        index: usize, // child index
        first: bool, // is first child
        last: bool, // is last child
    };
    const EntryList = std.ArrayList(Entry);

    //// Depth values:
    /// -1 : as deep as possible
    /// -2 : only if children are present
    ///  0 : do not expand
    ///  n : expand until depth `n`
    depth: i32 = -1,
    stack: EntryList,

    pub fn init(allocator: mem.Allocator, first: *Item, depth: i32) !Iterator {
        var stack = EntryList.init(allocator);
        try stack.append(.{
            .item = first,
            .depth = 0,
            .index = 0,
            .first = true,
            .last = true,
        });
        return .{
            .stack = stack,
            .depth = depth,
        };
    }

    pub fn deinit(self: *Iterator) void {
        self.stack.deinit();
    }

    pub fn next(self: *Iterator) ?Entry {
        if (self.stack.items.len == 0) {
            return null;
        }

        const last_or_null: ?Entry = self.stack.popOrNull();
        if (last_or_null) |last| {
            self.growStack(last) catch return null;
        }

        return last_or_null;
    }

    fn growStack(self: *Iterator, entry: Entry) !void {
        // Invalid depth value < -2
        if (self.depth < -2) {
            return;
        }

        // Append children only if present == -2
        if (self.depth == -2 and !entry.item.hasChildren()) {
            return;
        }

        // Don't append children deeper than configured
        if (self.depth >= 0 and entry.depth > self.depth) {
            return;
        }

        if (!try entry.item.isDir()) {
            return;
        }

        var children = try entry.item.children();
        for (0..children.items.len) |index| {
            // TODO: Add ignore patterns

            // Required because Items are popped off the stack.
            var reverse_index = children.items.len - 1 - index;
            var child_entry = getEntry(reverse_index, entry.depth, children);
            try self.stack.append(child_entry);
        }
    }
};

pub fn getEntry(index: usize, parent_depth: usize, children: ItemList) Iterator.Entry {
    const item = children.items[index];
    return .{
        .item = item,
        .index = index,
        .depth = parent_depth + 1,
        .first = index == 0,
        .last = index == children.items.len - 1,
    };
}

const testing = std.testing;
test "leaks in Manager" {
    var m = try Self.init(testing.allocator, ".");
    var r = m.root;
    _ = try m.up();
    try testing.expect(m.root != r);
    try testing.expectEqual(try m.findParent(r), m.root);

    var iter = try m.iterate(-1);
    defer iter.deinit();

    while (iter.next()) |itm| {
        _ = itm;
    }

    _ = try m.down(r);
    try testing.expectEqual(m.root, r);
    m.deinit();
}
