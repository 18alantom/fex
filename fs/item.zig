const std = @import("std");

const fs = std.fs;
const mem = std.mem;
const os = std.os;

const print = std.debug.print;

pub const ItemList = std.ArrayList(*Item);
pub const ItemError = error{
    StatError,
    NoParent,
    IsNotDirectory,
};

/// Item is a view into a file system item it can be a directory or a file
/// or something else. It should be initialized to a directory.
pub const Item = struct {
    allocator: mem.Allocator,
    abs_path_buf: [fs.MAX_PATH_BYTES]u8,
    abs_path_len: usize,
    _stat: ?os.Stat = null,
    _parent: ?*Self = null,
    _children: ?ItemList = null,

    const Self = @This();

    /// init_path can be absolute or relative paths if init_path is "." then cwd
    /// is opened.
    ///
    /// Note: init_path should always point to a dir.
    pub fn init(allocator: mem.Allocator, init_path: []const u8) !*Self {
        var dir = fs.cwd();
        if (init_path.len > 1 or init_path[0] != '.') {
            dir = try dir.openDir(init_path, .{});
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

    pub fn stat(self: *Self) !os.Stat {
        if (self._stat) |s| {
            return s;
        }

        // To sentinel terminated pointer
        var abs_path_w: [*:0]const u8 = @ptrCast(
            self.abs_path_buf[0 .. self.abs_path_len + 1].ptr,
        );

        var s: os.Stat = undefined;
        if (os.system.stat(abs_path_w, &s) != 0) {
            return ItemError.StatError;
        }

        self._stat = s;
        return self._stat.?;
    }

    pub fn isDir(self: *Self) !bool {
        const s = try self.stat();
        return os.S.ISDIR(s.mode);
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
            self._parent = try Item.init(self.allocator, parent_path);
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
            if (self.abs_path_len == ch.abs_path_len or
                mem.eql(
                u8,
                &self.abs_path_buf,
                &ch.abs_path_buf,
            )) {
                pc.items[i] = self;
                self.allocator.destroy(ch);
            }
        }
    }

    pub fn isOpen(self: *Self) bool {
        if (self._children != null) {
            return true;
        }
        return false;
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

        while (true) {
            var entry: ?fs.IterableDir.Entry = iter.next() catch break;
            if (entry == null) {
                break;
            }

            var item_ap = try fs.path.join(
                self.allocator,
                &[_][]const u8{ ap, entry.?.name },
            );
            defer self.allocator.free(item_ap);

            var item = try self.allocator.create(Self);
            @memcpy(item.abs_path_buf[0..item_ap.len], item_ap);
            item.abs_path_buf[item_ap.len] = 0;
            item.abs_path_len = item_ap.len;
            item._stat = null;
            item._parent = self;
            item._children = null;
            try contents.append(item);
        }

        self._children = contents;
        return contents;
    }

    pub fn deinitSkipChild(self: *Self, child: *Item) void {
        self.freeChildren(child);
        self.allocator.destroy(self);
    }

    pub fn freeChildren(self: *Self, child_to_skip: ?*Item) void {
        if (self._children == null) {
            return;
        }

        for (self._children.?.items) |i| {
            if (child_to_skip != null and child_to_skip.? == i) {
                continue;
            }

            var itm = i;
            itm.freeChildren(null);
            self.allocator.destroy(itm);
        }
        self._children.?.deinit();
        self._children = null;
    }
};

const testing = std.testing;
test "leaks in Item" {
    var item = try Item.init(testing.allocator, ".");

    var parent = try item.parent();
    var children = try item.children();
    defer {
        parent.deinitSkipChild(item);
        item.deinit();
    }

    _ = parent.abspath();
    _ = item.abspath();
    for (children.items) |itm| {
        _ = itm.abspath();
    }
}
