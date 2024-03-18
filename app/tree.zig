const std = @import("std");

const Manager = @import("../fs/Manager.zig");
const View = @import("./View.zig");
const tui = @import("../tui.zig");

const Entry = Manager.Iterator.Entry;

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;

const IndentList = std.ArrayList(bool);
const Draw = tui.Draw;
const bufStyle = tui.style.bufStyle;

// TreeView is required because `indent_list` needs to be
// computed to generate the indent string of the tree.
//
// Indent string consists of indent lines which connect
// sibling items in a file system.
//
// `indent_list` is a boolean list that indicates whether
// the current item at depth `d` being iterated over has
// non iterated siblings by checking if it's the first or
// the last item in the list.
pub const TreeView = struct {
    obuf: [2048]u8, // Content Buffer
    sbuf: [2048]u8, // Style Buffer

    allocator: mem.Allocator,
    indent_list: IndentList,

    const Self = @This();
    pub fn init(allocator: mem.Allocator) Self {
        var indent_list = IndentList.init(allocator);
        return .{
            .indent_list = indent_list,
            .allocator = allocator,
            .obuf = undefined,
            .sbuf = undefined,
        };
    }

    pub fn deinit(self: *Self) void {
        self.indent_list.deinit();
    }

    pub fn printLines(self: *Self, view: *const View, draw: Draw) !void {
        self.resetIndentList();

        // Need to iterate over items before the view buffer because
        // calculating the indent list depends on previous items.
        for (0..(view.last + 1)) |i| {
            const entry = view.buffer.items[i];

            std.debug.print("\n{s}\n", .{entry.item.name()});
            std.debug.print("\til_bef={any}\n", .{self.indent_list.items});
            try self.updateIndentList(entry);
            std.debug.print("\til_aft={any}\n", .{self.indent_list.items});

            if (i > view.last) {
                break;
            }

            if (i < view.first) {
                continue;
            }

            try self.printLine(i, view, draw);
        }
    }

    fn printLine(self: *Self, i: usize, view: *const View, draw: Draw) !void {
        const fg = if (view.cursor == i) tui.style.Color.red else tui.style.Color.default;
        const cursor_style = try bufStyle(&self.sbuf, .{ .fg = fg });

        var entry = view.buffer.items[i];
        const line_str = try self.line(entry);
        try draw.println(line_str, cursor_style);
    }

    fn resetIndentList(self: *Self) void {
        for (0..self.indent_list.items.len) |i| {
            self.indent_list.items[i] = false;
        }
    }

    /// prints a single line of a dir tree in tree view
    pub fn line(
        self: *Self,
        entry: Entry,
    ) ![]u8 {
        var prefix = try self.getPrefix(entry, &self.obuf);
        var suffix = try fmt.bufPrint(
            self.obuf[prefix.len..],
            " [{d:02},{d:02}] {s}",
            .{
                entry.index,
                entry.depth,
                entry.item.name(),
            },
        );

        return self.obuf[0..(prefix.len + suffix.len)];
    }

    fn getPrefix(self: *Self, entry: Entry, obuf: []u8) ![]u8 {
        var e = self.setIndentLines(entry, obuf).len;
        var ec = if (entry.last) "└───" else "├───";
        @memcpy(obuf[e .. e + ec.len], ec);
        e = e + ec.len;
        return obuf[0..e];
    }

    fn updateIndentList(self: *Self, entry: Manager.Iterator.Entry) !void {
        // default first value is `false`
        var prev: bool = false;

        if (self.indent_list.items.len <= entry.depth) {
            try self.indent_list.resize(entry.depth + 1);
        } else {
            // previous value, if present, gets inherited
            prev = self.indent_list.items[entry.depth];
        }

        // `true` if not last child, and either first
        // or previous sibling had a connection.
        self.indent_list.items[entry.depth] = !entry.last and (entry.first or prev);
    }

    fn setIndentLines(self: *Self, entry: Manager.Iterator.Entry, obuf: []u8) []u8 {
        var e: usize = 0;
        for (0..entry.depth) |i| {
            var ic = if (self.indent_list.items[i]) "│   " else "    ";
            @memcpy(
                obuf[e .. ic.len + e],
                ic,
            );
            e += ic.len;
        }
        return obuf[0..e];
    }
};
