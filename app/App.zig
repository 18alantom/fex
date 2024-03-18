const std = @import("std");
const tree = @import("./tree.zig");
const fsitem = @import("../fs/item.zig");
const tui = @import("../tui.zig");
const utils = @import("../utils.zig");

const Manager = @import("../fs/Manager.zig");
const View = @import("./View.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const bS = tui.style.bufStyle;
const terminal = tui.terminal;

const Item = fsitem.Item;
const ItemError = fsitem.ItemError;
const TreeView = tree.TreeView;

allocator: mem.Allocator,
manager: *Manager,

const State = {};

const Self = @This();

pub fn init(allocator: mem.Allocator, root: []const u8) !Self {
    return .{
        .allocator = allocator,
        .manager = try Manager.init(allocator, root),
    };
}

pub fn deinit(self: *Self) void {
    self.manager.deinit();
}

pub const Viewport = struct {
    // Terminal related fields
    size: terminal.Size, // terminal dims
    position: terminal.Position, // cursor position

    // Display related fields
    rows: u16 = 1, // max rows
    start_row: u16 = 0,

    pub fn init() !Viewport {
        try terminal.enableRawMode();
        return .{
            .rows = 0,
            .start_row = 0,
            .size = terminal.Size{ .cols = 0, .rows = 0 },
            .position = terminal.Position{ .col = 0, .row = 0 },
        };
    }

    pub fn deinit(_: *Viewport) void {
        terminal.disableRawMode() catch {};
    }

    pub fn setBounds(self: *Viewport) !void {
        self.size = terminal.getTerminalSize();
        self.position = try Viewport.getAdjustedPosition(self.size);
        self.rows = self.size.rows - self.position.row;
        self.start_row = Viewport.getStartRow(
            self.rows,
            self.position,
        );
    }

    fn getAdjustedPosition(size: terminal.Size) !terminal.Position {
        var position = try terminal.getCursorPosition();
        const min_rows = size.rows / 2;

        const rows_below = size.rows - position.row;
        if (rows_below > min_rows) {
            return position;
        }

        // Adjust Position: shift prompt (and cursor) up with newlines
        var obuf: [1024]u8 = undefined;
        var shift = min_rows - rows_below + 1;
        var newlines = utils.repeat(&obuf, "\n", shift);
        _ = try os.write(os.STDOUT_FILENO, newlines);

        return terminal.Position{
            .row = size.rows - shift,
            .col = position.col,
        };
    }

    fn getStartRow(rows: u16, pos: terminal.Position) u16 {
        if (pos.row > rows) {
            // unreachable after adjusted position
            return pos.row - rows;
        }

        return pos.row;
    }
};

const Output = struct {
    // Output
    draw: tui.Draw,
    writer: fs.File.Writer,

    tree_view: TreeView,
    obuf: [2048]u8, // Content Buffer
    sbuf: [2048]u8, // Style Buffer

    pub fn init(allocator: mem.Allocator) !Output {
        const writer = io.getStdOut().writer();
        const draw = tui.Draw{ .writer = writer };
        var tree_view = tree.TreeView.init(allocator);

        try draw.hideCursor();
        return .{
            .writer = writer,
            .draw = draw,
            .tree_view = tree_view,
            .obuf = undefined,
            .sbuf = undefined,
        };
    }

    pub fn deinit(self: *Output) void {
        self.draw.showCursor() catch {};
        self.tree_view.deinit();
    }

    pub fn printContents(self: *Output, start_row: u16, view: View) !void {
        try self.draw.moveCursor(start_row, 0);
        try self.tree_view.printLines(
            &view,
            self.draw,
        );

        // for (view.first..(view.last + 1)) |i| {
        //     const e = view.buffer.items[i];

        //     const fg = if (view.cursor == i) tui.style.Color.red else tui.style.Color.default;
        //     const cursor_style = try bS(&self.sbuf, .{ .fg = fg });

        //     var line = try tree_view.line(e, &self.obuf);
        //     try self.draw.println(line, cursor_style);
        // }
    }
};

pub const AppAction = enum {
    up,
    down,
    select,
    quit,
    top,
    bottom,
    depth_one,
    depth_two,
    depth_three,
    depth_four,
    depth_five,
    depth_six,
    depth_seven,
    depth_eight,
    depth_nine,
    expand_all,
    collapse_all,
};

const Input = struct {
    reader: fs.File.Reader,
    rbuf: [2048]u8,
    input: tui.Input,

    pub fn init() Input {
        const reader = io.getStdIn().reader();
        var input = tui.Input{ .reader = reader };
        return .{
            .reader = reader,
            .input = input,
            .rbuf = undefined,
        };
    }

    pub fn deinit(_: *Input) void {}

    pub fn getAppAction(self: *Input) !AppAction {
        while (true) {
            const key = try self.input.readKeys();
            std.debug.print("{any}\n", .{key});
            return switch (key) {
                .enter => AppAction.select,
                // Navigation
                .up => AppAction.up,
                .down => AppAction.down,
                .gg => AppAction.top,
                .G => AppAction.bottom,
                // Toggle fold
                .C => AppAction.collapse_all,
                .E => AppAction.expand_all,
                // Expand to depth
                .one => AppAction.depth_one,
                .two => AppAction.depth_two,
                .three => AppAction.depth_three,
                .four => AppAction.depth_four,
                .five => AppAction.depth_five,
                .six => AppAction.depth_six,
                .seven => AppAction.depth_seven,
                .eight => AppAction.depth_eight,
                .nine => AppAction.depth_nine,
                // Quit
                .q => AppAction.quit,
                .ctrl_c => AppAction.quit,
                .ctrl_d => AppAction.quit,
                else => continue,
            };
        }
    }
};

const Entry = Manager.Iterator.Entry;
pub fn run(self: *Self) !void {
    var vp = try Viewport.init();
    defer vp.deinit();

    try vp.setBounds();

    _ = try self.manager.root.children();

    // Buffer iterated elements to allow backtracking
    var view = View.init(self.allocator);
    defer view.deinit();

    var out = try Output.init(self.allocator);
    defer out.deinit();

    var inp = Input.init();
    defer inp.deinit();

    // Iterates over fs tree
    var reiterate = true;
    var iter_or_null: ?Manager.Iterator = null;
    defer {
        if (iter_or_null != null) iter_or_null.?.deinit();
    }

    var iter_mode: i32 = -2;
    while (true) {
        if (reiterate) {
            defer reiterate = false;
            view.buffer.clearAndFree();
            if (iter_or_null != null) iter_or_null.?.deinit();

            iter_or_null = try self.manager.iterate(iter_mode);

            var max_append = view.first + vp.rows;
            while (iter_or_null.?.next()) |e| {
                if (view.buffer.items.len > max_append) break;
                try view.buffer.append(e);
            }
            view.last = @min(max_append, view.buffer.items.len) - 1;
            iter_mode = -2;
        }

        try view.update(&iter_or_null.?);

        // Print contents of view buffer in range
        try out.printContents(vp.start_row, view);

        const app_action = try inp.getAppAction();
        switch (app_action) {
            .down => view.cursor += 1,
            .up => view.cursor -|= 1,
            .top => view.cursor = 0,
            .bottom => {
                while (iter_or_null.?.next()) |e| try view.buffer.append(e);
                view.cursor = view.buffer.items.len - 1;
            },
            .select => {
                const item = view.buffer.items[view.cursor].item;
                reiterate = try toggleChildren(item);
            },
            .expand_all => {
                iter_mode = -1;
                reiterate = true;
            },
            .collapse_all => {
                self.manager.root.freeChildren(null);
                view.cursor = 0;
                reiterate = true;
            },
            .depth_one => {
                iter_mode = 0;
                reiterate = true;
            },
            .depth_two => {
                iter_mode = 1;
                reiterate = true;
            },
            .depth_three => {
                iter_mode = 2;
                reiterate = true;
            },
            .depth_four => {
                iter_mode = 3;
                reiterate = true;
            },
            .depth_five => {
                iter_mode = 4;
                reiterate = true;
            },
            .depth_six => {
                iter_mode = 5;
                reiterate = true;
            },
            .depth_seven => {
                iter_mode = 6;
                reiterate = true;
            },
            .depth_eight => {
                iter_mode = 7;
                reiterate = true;
            },
            .depth_nine => {
                iter_mode = 8;
                reiterate = true;
            },
            .quit => return,
        }

        try out.draw.clearLinesBelow(vp.start_row);
    }
}

fn appendAll() void {}

fn toggleChildren(item: *Item) !bool {
    if (item.hasChildren()) {
        item.freeChildren(null);
        return true;
    }

    _ = item.children() catch |e| {
        switch (e) {
            ItemError.IsNotDirectory => return false,
            else => return e,
        }
    };
    return true;
}

test "test" {}
