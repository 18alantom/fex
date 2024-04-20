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

const Entry = Manager.Iterator.Entry;

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;

const IndentList = std.ArrayList(bool);
const Draw = tui.Draw;
const getStyle = tui.style.style;
const getIcon = icons.getIcon;

const Config = struct {
    show_icons: bool = true,
};

obuf: [2048]u8, // Content Buffer
sbuf: [2048]u8, // Style Buffer

allocator: mem.Allocator,
indent_list: IndentList,
config: Config,
print_size: bool,
print_mode: bool,
print_modified: bool,

const Self = @This();
pub fn init(allocator: mem.Allocator) Self {
    var indent_list = IndentList.init(allocator);
    return .{
        .indent_list = indent_list,
        .allocator = allocator,
        .obuf = undefined,
        .sbuf = undefined,
        .config = .{},
        .print_size = false,
        .print_mode = false,
        .print_modified = false,
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

    if (self.print_mode) {
        var mode = try getMode(entry, &self.obuf);
        try draw.print(mode, .{ .no_style = true });
    }

    if (self.print_size) {
        var size = try getSize(entry, &self.obuf);
        try draw.print(size, .{ .fg = .cyan });
    }

    if (self.print_modified) {}

    // Print tree branches
    var branch = try self.getBranch(entry, &self.obuf);
    try draw.print(branch, .{ .faint = true });

    // Print name
    const icon = if (self.config.show_icons) try getIcon(entry) else "\u{0008}";
    const out = try fmt.bufPrint(
        &self.obuf,
        "{s} {s}",
        .{ icon, entry.item.name() },
    );
    try draw.println(out, .{ .fg = try getFg(entry, view.cursor == i) });
}

fn getFg(entry: Entry, is_selected: bool) !tui.style.Color {
    if (is_selected) return .red;
    if (try entry.item.isDir()) return .blue;
    if (try entry.item.isExec()) return .green;
    return .default;
}

fn getBranch(self: *Self, entry: Entry, obuf: []u8) ![]u8 {
    var e = self.setIndentLines(entry, obuf).len;
    var ec = if (entry.last) "└── " else "├── ";
    @memcpy(obuf[e .. e + ec.len], ec);
    e = e + ec.len;
    return obuf[0..e];
}

fn getSize(entry: Entry, obuf: []u8) ![]u8 {
    var raw_size = try entry.item.size();
    var size = @max(@as(f64, @floatFromInt(raw_size)), 0);
    if (size < 1000) {
        return fmt.bufPrint(obuf, "{d:7} ", .{size});
    }

    if (size < 1_000_000) {
        size /= 1_000;
        return fmt.bufPrint(obuf, "{d:6.1}k ", .{size});
    }

    if (size < 1_000_000_000) {
        size /= 1_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}M ", .{size});
    }

    if (size < 1_000_000_000_000) {
        size /= 1_000_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}G ", .{size});
    }

    if (size < 1_000_000_000_000_000) {
        size /= 1_000_000_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}T ", .{size});
    }

    if (size < 1_000_000_000_000_000_000) {
        size /= 1_000_000_000_000_000;
        return fmt.bufPrint(obuf, "{d:6.1}P ", .{size});
    }

    return fmt.bufPrint(obuf, "{d:7} ", .{0});
}

fn getMode(entry: Entry, obuf: []u8) ![]u8 {
    const item = entry.item;
    const mode = try item.mode();

    // Color string consts
    const d = "\x1b[34md\x1b[m"; // Blue 'd'
    const l = "\x1b[36ml\x1b[m"; // Cyan 'l'
    const x = "\x1b[32mx\x1b[m"; // Green 'x'
    const w = "\x1b[33mw\x1b[m"; // Yellow 'w'
    const r = "\x1b[31mr\x1b[m"; // Red 'r'
    const dash = "-";

    const item_type = if (try item.isDir()) d else if (try item.isLink()) l else " ";
    // User perms
    const exec_user = if (mode & os.S.IXUSR > 0) x else dash; // & 0o100
    const write_user = if (mode & os.S.IWUSR > 0) w else dash; // & 0o200
    const read_user = if (mode & os.S.IRUSR > 0) r else dash; // & 0o400
    // Group perms
    const exec_group = if (mode & os.S.IXGRP > 0) x else dash; // & 0o10
    const write_group = if (mode & os.S.IWGRP > 0) w else dash; // & 0o20
    const read_group = if (mode & os.S.IRGRP > 0) r else dash; // & 0o40
    // Other perms
    const exec_other = if (mode & os.S.IXOTH > 0) x else dash; // & 0o1
    const write_other = if (mode & os.S.IWOTH > 0) w else dash; // & 0o2
    const read_other = if (mode & os.S.IROTH > 0) r else dash; // & 0o4

    return fmt.bufPrint(obuf, "{s}{s}{s}{s}{s}{s}{s}{s}{s}{s} ", .{
        item_type,
        // User
        exec_user,
        write_user,
        read_user,
        // Group
        exec_group,
        write_group,
        read_group,
        // Other
        exec_other,
        write_other,
        read_other,
    });
}
