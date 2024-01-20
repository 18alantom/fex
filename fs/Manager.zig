const std = @import("std");

const _item = @import("./item.zig");
const Item = _item.Item;
const ItemError = _item.ItemError;

const fs = std.fs;
const mem = std.mem;
const os = std.os;

const print = std.debug.print;

const Self = @This();

root: *Item,
allocator: mem.Allocator,

pub fn init(allocator: mem.Allocator) !*Self {
    var m = try allocator.create(Self);

    m.root = try Item.init(allocator, ".");
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
    if (!parent.isOpen()) {
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

pub fn walk() void {}

const testing = std.testing;
test "leaks in Manager" {
    var m = try Self.init(testing.allocator);
    var r = m.root;
    _ = try m.up();
    try testing.expect(m.root != r);
    try testing.expectEqual(try m.findParent(r), m.root);
    _ = try m.down(r);
    try testing.expectEqual(m.root, r);
    m.deinit();
}
