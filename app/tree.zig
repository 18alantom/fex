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
        for (0..view.last) |i| {
            if (i > view.last) {
                break;
            }

            const entry = view.buffer.items[i];
            try self.updateIndentList(entry);

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
        std.debug.print("\nil_bef={any} {s}\n", .{ self.indent_list.items, entry.item.name() });
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

        std.debug.print("il_aft={any}\n", .{self.indent_list.items});
        return self.obuf[0..(prefix.len + suffix.len)];
    }

    fn getPrefix(self: *Self, entry: Entry, obuf: []u8) ![]u8 {
        try self.updateIndentList(entry);
        var e = self.setIndentLines(entry, obuf).len;
        var ec = if (entry.last) "└───" else "├───";
        @memcpy(obuf[e .. e + ec.len], ec);
        e = e + ec.len;
        return obuf[0..e];
    }

    fn updateIndentList(self: *Self, entry: Manager.Iterator.Entry) !void {
        var resized = false;
        if (self.indent_list.items.len <= entry.depth) {
            try self.indent_list.resize(entry.depth + 1);
            resized = true;
        }

        var val = false;
        var prev = if (resized) false else self.indent_list.items[entry.depth];

        // if first then iterating over siblings and their children,
        // indent line should be drawn to connect the siblings
        //
        // valid transition: to start a new line, previous should have
        // ended i.e indent list would be false.
        if (entry.first and !prev) {
            val = true;
        }

        // if last then not in list and line should not be drawn
        //
        // valid transition: to end a line, it should have been
        // started or the item should be the first and the last
        if (entry.last and (prev or entry.first)) {
            val = false;
        }
        self.indent_list.items[entry.depth] = val;
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
