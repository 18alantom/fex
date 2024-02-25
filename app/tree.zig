const std = @import("std");
const Manager = @import("../fs/Manager.zig");

const Entry = Manager.Iterator.Entry;

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;

const print = std.debug.print;

const IndentList = std.ArrayList(bool);

// TreeView is required because `indent_list` needs to be
// computed to generate the indent string of the tree.
//
// `indent_list` is a boolean list that indicates whether
// there's a sibling node at depth `index`.
pub const TreeView = struct {
    allocator: mem.Allocator,
    indent_list: IndentList,

    const Self = @This();
    pub fn init(allocator: mem.Allocator) Self {
        var indent_list = IndentList.init(allocator);
        return .{ .indent_list = indent_list, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.indent_list.deinit();
    }

    /// prints a single line of a dir tree in tree view
    pub fn line(
        self: *Self,
        entry: Entry,
        obuf: []u8,
    ) ![]u8 {
        var prefix = try self.getPrefix(entry, obuf);
        var suffix = try fmt.bufPrint(
            obuf[prefix.len..],
            " [{d:02},{d:02}] {s}",
            .{
                entry.index,
                entry.depth,
                entry.item.name(),
            },
        );

        return obuf[0..(prefix.len + suffix.len)];
    }

    fn getPrefix(self: *Self, entry: Entry, obuf: []u8) ![]u8 {
        try self.setIndentList(entry);
        var e = self.setIndentLines(entry, obuf).len;
        var ec = if (entry.last) "└───" else "├───";
        @memcpy(obuf[e .. e + ec.len], ec);
        e = e + ec.len;
        return obuf[0..e];
    }

    fn setIndentList(self: *Self, entry: Manager.Iterator.Entry) !void {
        try self.indent_list.resize(entry.depth + 1);
        self.indent_list.items[entry.depth] = entry.last;
    }

    fn setIndentLines(self: *Self, entry: Manager.Iterator.Entry, obuf: []u8) []u8 {
        var e: usize = 0;
        for (0..entry.depth) |i| {
            var ic = if (self.indent_list.items[i]) "    " else "│   ";
            @memcpy(
                obuf[e .. ic.len + e],
                ic,
            );
            e += ic.len;
        }
        return obuf[0..e];
    }
};
