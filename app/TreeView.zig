/// TreeView is responsible for formatting values in View.buffer
/// into output strings.
///
/// It is required because `indent_list` needs to be calculated to
/// generate the indent string of the tree.
///
/// Indent string consists of indent lines which connect sibling
/// items in a file system.
///
/// `indent_list` is a boolean list that indicates whether the
/// current item at depth `d` being iterated over has non iterated
/// siblings by checking if it's the first or the last item in the
/// list.
const std = @import("std");

const Manager = @import("../fs/Manager.zig");
const icons = @import("./icons.zig");
const View = @import("./View.zig");
const tui = @import("../tui.zig");
const statfmt = @import("../fs/statfmt.zig");
const Stat = @import("../fs/Stat.zig");

const Entry = Manager.Iterator.Entry;

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;

const IndentList = std.ArrayList(bool);
const Draw = tui.Draw;
const getStyle = tui.style.style;
const getIcon = icons.getIcon;

const Info = struct {
    icons: bool = true,
    size: bool = true,
    mode: bool = true,
    modified: bool = true,
    changed: bool = false,
    accessed: bool = false,
    show: bool = true,
};

obuf: [2048]u8, // Content Buffer
sbuf: [2048]u8, // Style Buffer

allocator: mem.Allocator,
indent_list: IndentList,
info: Info,

const Self = @This();
pub fn init(allocator: mem.Allocator) Self {
    var indent_list = IndentList.init(allocator);
    return .{
        .indent_list = indent_list,
        .allocator = allocator,
        .obuf = undefined,
        .sbuf = undefined,
        .info = .{},
    };
}

pub fn deinit(self: *Self) void {
    self.indent_list.deinit();
}

pub fn printLines(
    self: *Self,
    view: *View,
    draw: *Draw,
    start_row: usize,
) !void {
    self.resetIndentList();
    try draw.moveCursor(start_row, 0);

    // Need to iterate over items before the view buffer because
    // calculating the indent list depends on previous items.
    for (0..(view.last + 1)) |i| {
        const entry = view.buffer.items[i];

        try self.updateIndentList(entry);
        if (i > view.last) {
            break;
        }

        if (i < view.first) {
            continue;
        }

        if (view.print_all) {
            try self.printLine(i, view, draw);
        } else if (i == view.cursor or i == view.prev_cursor) {
            var row = start_row + (i - view.first);
            try draw.moveCursor(row, 0);
            try self.printLine(i, view, draw);
        }
    }
    view.print_all = false;
}

fn resetIndentList(self: *Self) void {
    for (0..self.indent_list.items.len) |i| {
        self.indent_list.items[i] = false;
    }
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

fn printLine(self: *Self, i: usize, view: *const View, draw: *Draw) !void {
    try draw.clearLine();
    var entry = view.buffer.items[i];

    if (self.info.show and self.info.mode) {
        var mode = try statfmt.mode(try entry.item.stat(), &self.obuf);
        try draw.print(mode, .{ .no_style = true });
    }

    if (self.info.show and self.info.size) {
        var size = try statfmt.size(try entry.item.stat(), &self.obuf);
        try draw.print(size, .{ .fg = .cyan });
    }

    if (self.timeType()) |time_type| {
        var time = statfmt.time(try entry.item.stat(), time_type, &self.obuf);
        try draw.print(time, .{ .fg = .yellow });
    }

    // Print tree branches
    var branch = try self.getBranch(entry, &self.obuf);
    try draw.print(branch, .{ .faint = true });

    // Print name
    const icon = if (self.info.icons) try getIcon(entry) else "\u{0008}";
    const out = try fmt.bufPrint(
        &self.obuf,
        "{s} {s}",
        .{ icon, entry.item.name() },
    );
    try draw.println(out, .{ .fg = try getFg(entry, view.cursor == i) });
}

fn timeType(self: *Self) ?Stat.TimeType {
    if (!self.info.show) return null;

    if (self.info.modified) return .mtime;
    if (self.info.accessed) return .atime;
    if (self.info.changed) return .ctime;
    return null;
}

fn getFg(entry: Entry, is_selected: bool) !tui.style.Color {
    if (is_selected) return .red;
    const s = try entry.item.stat();

    if (s.isDir()) return .blue;
    if (s.isLink()) return .cyan;
    if (s.isExec()) return .green;
    return .default;
}

fn getBranch(self: *Self, entry: Entry, obuf: []u8) ![]u8 {
    var e = self.setIndentLines(entry, obuf).len;
    var ec = if (entry.last) "└── " else "├── ";
    @memcpy(obuf[e .. e + ec.len], ec);
    e = e + ec.len;
    return obuf[0..e];
}
