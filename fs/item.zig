const std = @import("std");

const os = std.os;
const fs = std.fs;
const path = std.fs.path;
const heap = std.heap;
const mem = std.mem;
const print = std.debug.print;

const ItemList = std.ArrayList(Item);

/// Item is a view into a file system item
const Item = struct {
    allocator: mem.Allocator,
    abs_path_buf: [fs.MAX_PATH_BYTES]u8,
    abs_path_len: usize,
    _stat: ?os.Stat = null,
    _parent: ?*Self = null,
    _children: ?ItemList = null,

    const Self = @This();

    /// init_path can be absolute or relative paths
    /// if init_path is "." then cwd is opened.
    ///
    /// Note: init_path should always point to a dir.
    pub fn init(self: *Self, allocator: mem.Allocator, init_path: []const u8) !void {
        var dir = fs.cwd();
        if (init_path.len > 1 or init_path[0] != '.') {
            dir = try dir.openDir(init_path, .{});
        }

        var abs_path = try dir.realpath(".", &self.abs_path_buf);
        self.allocator = allocator;
        self.abs_path_buf[abs_path.len] = 0; // sentinel termination
        self.abs_path_len = abs_path.len; // set len
        self._stat = null;
        self._parent = null;
        self._children = null;
    }

    /// When deinit is called all returned parent and children are
    /// invalidated.
    pub fn deinit(self: *Self) void {
        self.freeParent();
        self.freeChildren();
    }

    pub fn abspath(self: *const Self) []const u8 {
        return self.abs_path_buf[0..self.abs_path_len];
    }

    pub fn name(self: *const Self) []const u8 {
        const abs_path = self.abs_path_buf[0..self.abs_path_len];
        return path.basename(abs_path);
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
            return error.StatError;
        }

        self._stat = s;
        return self._stat.?;
    }

    pub fn isDir(self: *Self) !bool {
        const s = try self.stat();
        return os.S.ISDIR(s.mode);
    }

    pub fn parent(self: *Self) !*Self {
        if (self._parent) |p| {
            return p;
        }

        if (fs.path.dirname(self.abspath())) |parent_path| {
            self._parent = try self.allocator.create(Self);
            try self._parent.?.init(self.allocator, parent_path);
            return self._parent.?;
        }

        return error.NoParent;
    }

    pub fn freeParent(self: *Self) void {
        if (self._parent == null) {
            return;
        }

        self._parent.?.deinit();
        self.allocator.destroy(self._parent.?);
        self._parent = null;
    }

    pub fn children(self: *Self) !ItemList {
        if (!try self.isDir()) {
            return error.IsNotDirectory;
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

            var item_ptr: *Self = try contents.addOne();
            @memcpy(item_ptr.abs_path_buf[0..item_ap.len], item_ap);
            item_ptr.abs_path_buf[item_ap.len] = 0;
            item_ptr.abs_path_len = item_ap.len;
            item_ptr._stat = null;
            item_ptr._parent = self;
            item_ptr._children = null;
        }

        self._children = contents;
        return contents;
    }

    pub fn freeChildren(self: *Self) void {
        if (self._children == null) {
            return;
        }

        for (self._children.?.items) |i| {
            var itm = i;
            itm.freeChildren();
        }
        self._children.?.deinit();
        self._children = null;
    }
};

const testing = std.testing;
test "stuff" {
    var item: Item = undefined;
    try item.init(testing.allocator, ".");
    defer item.deinit();
    var parent = try item.parent();
    var children = try item.children();

    print("\n{s}\n", .{parent.abspath()});
    print("{s}\n", .{item.abspath()});
    for (children.items) |itm| {
        print("{s}\n", .{itm.abspath()});
    }
}

pub fn printStat(s: os.Stat) void {
    print("stat :: uid={d}, gid={d}, mode={d}, size={d}\n", .{ s.uid, s.gid, s.mode, s.size });
}
