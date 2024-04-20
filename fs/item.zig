const std = @import("std");
const Stat = @import("./Stat.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;

const print = std.debug.print;

const Self = @This();
pub const ItemList = std.ArrayList(*Self);
pub const ItemError = error{
    StatError,
    NoParent,
    IsNotDirectory,
};

/// Item is a view into a file system item it can be a directory or a file
/// or something else. It should be initialized to a directory.
allocator: mem.Allocator,
abs_path_buf: [fs.MAX_PATH_BYTES]u8,
abs_path_len: usize,
_stat: ?Stat = null,
_parent: ?*Self = null,
_children: ?ItemList = null,

/// init_path can be absolute or relative paths if init_path is "." then cwd
/// is opened.
///
/// Note: init_path should always point to a dir.
pub fn init(allocator: mem.Allocator, root: []const u8) !*Self {
    var dir = fs.cwd();
    if (root.len > 1 or root[0] != '.') {
        dir = try dir.openDir(root, .{});
    }

    var item = try allocator.create(Self);
    var abs_path = try dir.realpath(".", &item.abs_path_buf);
    item.allocator = allocator;
    item.abs_path_buf[abs_path.len] = 0; // sentinel termination
    item.abs_path_len = abs_path.len; // set len
    item._stat = null;
    item._parent = null;
    item._children = null;
    return item;
}

/// Frees all children and invalidates self. Should be called from parent if
/// present. If
pub fn deinit(self: *Self) void {
    self.freeChildren(null);
    self.allocator.destroy(self);
}

/// Returns absolute path.
pub fn abspath(self: *const Self) []const u8 {
    return self.abs_path_buf[0..self.abs_path_len];
}

/// Returns name of the Item.
pub fn name(self: *const Self) []const u8 {
    const abs_path = self.abs_path_buf[0..self.abs_path_len];
    return fs.path.basename(abs_path);
}

/// Returns path to the containing directory.
pub fn dirpath(self: *const Self) ?[]const u8 {
    return fs.path.dirname(self.abspath());
}

pub fn stat(self: *Self) !Stat {
    if (self._stat) |s| {
        return s;
    }

    self._stat = try Stat.stat(self.abspath());
    return self._stat.?;
}

pub fn isDir(self: *Self) !bool {
    return (try self.stat()).isDir();
}

pub fn isExec(self: *Self) !bool {
    return (try self.stat()).isExec();
}

pub fn isLink(self: *Self) !bool {
    return (try self.stat()).isLink();
}

pub fn mode(self: *Self) !u16 {
    return (try self.stat()).mode;
}

pub fn size(self: *Self) !i64 {
    return (try self.stat()).size;
}

/// Returns Item that references the parent directory of the calling Item.
/// Initializes parents children and sets self in the list of children.
///
/// Once parent has been created, deinit should be called on parent which
/// recursively frees all children. If instead a child is to be skipped while
/// deinit-ing the parent call `deinitSkipChild`.
pub fn parent(self: *Self) !*Self {
    if (self._parent) |p| {
        return p;
    }

    if (self.dirpath()) |parent_path| {
        self._parent = try Self.init(self.allocator, parent_path);
        try self.setParentsChildren();
        return self._parent.?;
    }

    return ItemError.NoParent;
}

fn setParentsChildren(self: *Self) !void {
    if (self._parent == null) {
        return;
    }

    var p = self._parent.?;
    var pc: ItemList = try p.children();
    for (0..pc.items.len) |i| {
        var ch = pc.items[i];
        if (self.abs_path_len == ch.abs_path_len and
            mem.eql(
            u8,
            &self.abs_path_buf,
            &ch.abs_path_buf,
        )) {
            pc.items[i] = self;
            self.allocator.destroy(ch);
            return;
        }
    }
    // unreachable; // ideally, but not always
    //
    // If the code execution reaches here, then there's
    // a possibility of a memory leak if references to the
    // item calling this function are lost because they will
    // not be under the parent's child list.
    //
    // The function `self.parent` is responsible for freeing
    // the orphaned child tree in such a case.
}

pub fn hasChildren(self: *Self) bool {
    return self._children != null;
}

pub fn hasParent(self: *Self) bool {
    return self._parent != null;
}

/// Initializes children if not present and returns it. If `deinit` or
/// `freeChildren` is called, the returned ItemList of children are invalidated.
pub fn children(self: *Self) !ItemList {
    if (!try self.isDir()) {
        return ItemError.IsNotDirectory;
    }

    if (self._children) |contents| {
        return contents;
    }

    const ap = self.abspath();

    var dir = try fs.openDirAbsolute(ap, .{});
    var idir = try dir.openIterableDir(".", .{});
    var iter = idir.iterate();
    var contents = ItemList.init(self.allocator);

    // Will not work on windows
    var is_root = self.abs_path_len == 1 and self.abs_path_buf[0] == '/';
    while (true) {
        var entry: ?fs.IterableDir.Entry = iter.next() catch break;
        if (entry == null) {
            break;
        }

        var item = try self.allocator.create(Self);
        var len: usize = 0;

        @memcpy(item.abs_path_buf[0..ap.len], ap);
        if (is_root) {
            len = ap.len + entry.?.name.len;
            @memcpy(item.abs_path_buf[(ap.len)..len], entry.?.name);
        } else {
            item.abs_path_buf[ap.len] = fs.path.sep;
            len = ap.len + 1 + entry.?.name.len;
            @memcpy(item.abs_path_buf[(ap.len + 1)..len], entry.?.name);
        }
        item.abs_path_buf[len] = 0;
        item.abs_path_len = len;

        item._stat = null;
        item._parent = self;
        item._children = null;
        item.allocator = self.allocator;
        try contents.append(item);
    }

    self._children = contents;
    return contents;
}

pub fn indexOfChild(self: *Self, child: *Self) !?usize {
    if (self._children == null) {
        return null;
    }

    for (self._children.?.items, 0..) |c, i| {
        if (c == child) {
            return i;
        }
    }
    return null;
}

pub fn deinitSkipChild(self: *Self, child: *Self) void {
    self.freeChildren(child);
    self.allocator.destroy(self);
}

pub fn freeChildren(self: *Self, child_to_skip: ?*Self) void {
    if (self._children == null) {
        return;
    }

    for (self._children.?.items) |i| {
        if (child_to_skip != null and child_to_skip.? == i) {
            child_to_skip.?._parent = null;
            continue;
        }

        var itm = i;
        itm.freeChildren(child_to_skip);
        self.allocator.destroy(itm);
    }
    self._children.?.deinit();
    self._children = null;
}

const testing = std.testing;
test "leaks in Item" {
    var item = try Self.init(testing.allocator, ".");

    var prnt = try item.parent();
    var chld = try item.children();
    defer {
        prnt.deinitSkipChild(item);
        item.deinit();
    }

    _ = prnt.abspath();
    _ = item.abspath();
    for (chld.items) |itm| {
        _ = itm.abspath();
    }
}
