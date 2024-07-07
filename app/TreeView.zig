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

const tui = @import("../tui.zig");
const args = @import("./args.zig");
const icons = @import("./icons.zig");
const string = @import("../utils/string.zig");
const statfmt = @import("../fs/statfmt.zig");

const App = @import("./App.zig");
const Stat = @import("../fs/Stat.zig");
const View = @import("./View.zig");
const Manager = @import("../fs/Manager.zig");

const Entry = Manager.Iterator.Entry;
const SearchQuery = string.SearchQuery;
const Config = App.Config;

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;
const posix = std.posix;

const IndentList = std.ArrayList(bool);
const Draw = tui.Draw;
const getStyle = tui.style.style;
const getIcon = icons.getIcon;
const log = std.log.scoped(.treeview);

const Info = struct {
    icons: bool = true,
    size: bool = true,
    perm: bool = true,
    time: bool = true,
    modified: bool = true,
    changed: bool = false,
    accessed: bool = false,
    link: bool = true,
    group: bool = false,
    user: bool = false,
    show: bool = true,
};

obuf: [2048]u8, // Content Buffer
sbuf: [2048]u8, // Style Buffer

allocator: mem.Allocator,
indent_list: *IndentList,
info: Info,

// Used to store gid, uid names
gmap: *Stat.IDNameMap,
umap: *Stat.IDNameMap,

const Self = @This();
pub fn init(allocator: mem.Allocator, config: *Config) !Self {
    const indent_list = try allocator.create(IndentList);
    indent_list.* = IndentList.init(allocator);

    const gmap = try allocator.create(Stat.IDNameMap);
    gmap.* = Stat.IDNameMap.init(allocator);

    const umap = try allocator.create(Stat.IDNameMap);
    umap.* = Stat.IDNameMap.init(allocator);
    return .{
        .indent_list = indent_list,
        .allocator = allocator,
        .obuf = undefined,
        .sbuf = undefined,
        .info = .{
            .icons = config.icons,
            .size = config.size,
            .perm = config.perm,
            .time = config.time,
            .link = config.link,
            .modified = config.time_type == .modified,
            .changed = config.time_type == .changed,
            .accessed = config.time_type == .accessed,
            .show = config.icons or config.size or config.perm or config.time or config.link,
        },
        .gmap = gmap,
        .umap = umap,
    };
}

pub fn deinit(self: *Self) void {
    self.indent_list.deinit();
    self.allocator.destroy(self.indent_list);

    Stat.deinitIdNameMap(self.gmap);
    self.allocator.destroy(self.gmap);

    Stat.deinitIdNameMap(self.umap);
    self.allocator.destroy(self.umap);
}

pub fn printLines(
    self: *Self,
    view: *View,
    draw: *Draw,
    start_row: usize,
    search_query: ?*const SearchQuery,
    is_capturing_command: bool,
) !void {
    self.resetIndentList();
    try draw.moveCursor(start_row, 0);

    var gum: GidUidMax = .{ .gid_max = 0, .uid_max = 0 };
    if (self.info.show and (self.info.group or self.info.user)) {
        try self.setGidUidMaxLen(view, &gum);
    }

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

        const render_last = is_capturing_command and view.last == i;

        // Assumes that cursor is at the right position.
        if (search_query != null or view.print_all) {
            try self.printLine(i, view, draw, search_query, &gum);
        }

        // Move cursor to line and render it.
        else if (i == view.cursor or i == view.prev_cursor or render_last) {
            const row = start_row + (i - view.first);
            try draw.moveCursor(row, 0);
            try self.printLine(i, view, draw, null, &gum);
        }
    }
    view.print_all = false;
}

const GidUidMax = struct {
    gid_max: usize,
    uid_max: usize,
};

fn setGidUidMaxLen(self: *Self, view: *View, gum: *GidUidMax) !void {
    for (0..(view.last + 1)) |i| {
        const entry = view.buffer.items[i];

        if (i > view.last) break;
        if (i < view.first) continue;

        const s = try entry.item.stat();

        const group = try s.getGroupName(self.gmap);
        gum.gid_max = @max(gum.gid_max, group.len);

        const user = try s.getUserName(self.umap);
        gum.uid_max = @max(gum.uid_max, user.len);
    }
}

fn resetIndentList(self: *Self) void {
    for (0..self.indent_list.items.len) |i| {
        self.indent_list.items[i] = false;
    }
}

fn updateIndentList(self: *Self, entry: *Entry) !void {
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

fn setIndentLines(self: *Self, entry: *Entry, obuf: []u8) []u8 {
    var e: usize = 0;
    for (0..entry.depth) |i| {
        const ic = if (self.indent_list.items[i]) "│   " else "    ";
        @memcpy(
            obuf[e .. ic.len + e],
            ic,
        );
        e += ic.len;
    }
    return obuf[0..e];
}

fn printLine(
    self: *Self,
    i: usize,
    view: *const View,
    draw: *Draw,
    search_query_or_null: ?*const SearchQuery,
    gum: *GidUidMax,
) !void {
    try draw.clearLine();
    var entry = view.buffer.items[i];
    const has_prefix_info = self.info.show and (self.info.perm or
        self.info.size or
        self.info.user or
        self.info.group or
        self.info.time);

    // Print permission info
    if (self.info.show and self.info.perm) {
        const mode = try statfmt.mode(try entry.item.stat(), &self.obuf);
        try draw.print(mode, .{ .no_style = true });
    }

    // Print size
    if (self.info.show and self.info.size) {
        const size = try statfmt.size(try entry.item.stat(), &self.obuf);
        try draw.print(size, .{ .fg = .cyan });
    }

    // Print User Name
    if (self.info.show and self.info.user) {
        const s = try entry.item.stat();
        const user = string.rpad(
            try s.getUserName(self.umap),
            gum.uid_max + 1,
            ' ',
            &self.obuf,
        );
        try draw.print(user, .{ .fg = .blue });
    }

    // Print Group Name
    if (self.info.show and self.info.group) {
        const s = try entry.item.stat();
        const group = string.rpad(
            try s.getGroupName(self.gmap),
            gum.gid_max + 1,
            ' ',
            &self.obuf,
        );
        try draw.print(group, .{ .fg = .green });
    }

    // Print time
    if (self.timeType()) |time_type| {
        const time = statfmt.time(try entry.item.stat(), time_type, &self.obuf);
        try draw.print(time, .{ .fg = .yellow });
    }

    if (has_prefix_info) {
        try draw.print(" ", .{ .no_style = true });
    }

    // Print tree branches
    const branch = try self.getBranch(entry, &self.obuf);
    try draw.print(branch, .{ .faint = true });

    // Print icons
    if (self.info.icons) {
        const icon = try getIcon(entry);
        try draw.print(icon, .{ .fg = try getFg(entry, false) });
        try draw.print(" ", .{ .no_style = true });
    }

    // Print name
    const name = if (search_query_or_null) |search_query|
        try string.searchHighlight(&self.obuf, entry.item.name(), search_query)
    else
        entry.item.name();
    try draw.print(
        name,
        .{ .fg = try getFg(entry, view.cursor == i), .underline = entry.selected },
    );

    if (self.info.link and try entry.item.isLink()) {
        const link_slc = try posix.readlink(
            entry.item.abspath(),
            &self.obuf,
        );
        try draw.print(" -> ", .{ .no_style = true });
        try draw.print(link_slc, .{ .fg = .red });
    }

    // Print cursor
    if (view.cursor == i) {
        try draw.print(" <", .{ .bold = true, .fg = .magenta });
    }
    try draw.println("", .{ .no_style = true });
}

fn timeType(self: *Self) ?Stat.TimeType {
    if (!self.info.show or !self.info.time) return null;

    if (self.info.modified) return .modified;
    if (self.info.accessed) return .accessed;
    if (self.info.changed) return .changed;
    return .modified;
}

fn getFg(entry: *Entry, is_selected: bool) !tui.style.Color {
    if (is_selected) return .magenta;
    const s = try entry.item.stat();

    if (s.isDir()) return .blue;
    if (s.isLink()) return .cyan;
    if (s.isExec()) return .green;
    if (s.isChr() or s.isBlock()) return .yellow;
    return .default;
}

fn getBranch(self: *Self, entry: *Entry, obuf: []u8) ![]u8 {
    var e = self.setIndentLines(entry, obuf).len;
    const ec = if (entry.last) "└── " else "├── ";
    @memcpy(obuf[e .. e + ec.len], ec);
    e = e + ec.len;
    return obuf[0..e];
}
