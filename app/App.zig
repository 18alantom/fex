const std = @import("std");
const tree = @import("./tree.zig");
const Manager = @import("../fs/Manager.zig");
const tui = @import("../tui.zig");
const utils = @import("../utils.zig");

const fs = std.fs;
const mem = std.mem;
const os = std.os;
const io = std.io;

const print = std.debug.print;
const bS = tui.style.bufStyle;
const terminal = tui.terminal;

allocator: mem.Allocator,
manager: *Manager,

const State = {};

const Self = @This();

pub fn init(allocator: mem.Allocator) !Self {
    return .{
        .allocator = allocator,
        .manager = try Manager.init(allocator),
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
        std.debug.print(
            "vp.setBounds size={any}, position={any}, rows={any}, start_row={any}\n",
            .{ self.size, self.position, self.rows, self.start_row },
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

pub const View = struct {
    allocator: mem.Allocator,
    buffer: std.ArrayList(Entry),

    first: usize, // first index (top buffer boundary)
    last: usize, // last index (bottom buffer boundar)
    cursor: usize, // location in buffer boundary

    pub fn init(allocator: mem.Allocator) View {
        return .{
            .allocator = allocator,
            .buffer = std.ArrayList(Entry).init(allocator),
            .cursor = 0,
            .first = 0,
            .last = 0,
        };
    }

    fn deinit(self: *View) void {
        self.buffer.deinit();
    }

    pub fn update(self: *View, iter: Manager.Iterator) !void {
        // Cursor exceeds bottom boundary
        if (self.cursor > self.last) {
            try self.updateBottomBounds(iter);
        }

        // Cursor exceeds top boundary
        else if (self.cursor < self.first) {
            self.updateTopBounds();
        }
    }

    fn updateBottomBounds(self: *View, _iter: Manager.Iterator) !void {
        var iter = _iter; // _iter is const

        // View buffer in range, no need to append
        if (self.last < (self.buffer.items.len - 1)) {
            self.first += 1;
            self.last += 1;
        }

        // View buffer out of range, need to append
        else if (iter.next()) |e| {
            try self.buffer.append(e);
            self.first += 1;
            self.last += 1;
        }

        // No more items, reset cursor
        else {
            self.cursor = self.last;
        }
    }

    fn updateTopBounds(self: *View) void {
        self.first -= 1;
        self.last -= 1;
    }
};

const Output = struct {
    // Output
    draw: tui.Draw,
    writer: fs.File.Writer,
    obuf: [2048]u8, // Content Buffer
    sbuf: [2048]u8, // Style Buffer

    pub fn init() !Output {
        const writer = io.getStdOut().writer();
        const draw = tui.Draw{ .writer = writer };

        try draw.hideCursor();
        return .{
            .writer = writer,
            .draw = draw,
            .obuf = undefined,
            .sbuf = undefined,
        };
    }

    pub fn deinit(self: *Output) void {
        self.draw.showCursor() catch {};
    }

    pub fn printContents(self: *Output, start_row: u16, view: View, tree_view: tree.TreeView) !void {
        try self.draw.moveCursor(start_row, 0);
        var tv = tree_view;
        for (view.first..(view.last + 1)) |i| {
            const e = view.buffer.items[i];

            const fg = if (view.cursor == i) tui.style.Color.cyan else tui.style.Color.default;
            const cursor_style = try bS(&self.sbuf, .{ .fg = fg });

            var line = try tv.line(e, &self.obuf);
            try self.draw.println(line, cursor_style);
        }
    }
};

pub const AppAction = enum {
    up,
    down,
    select,
    quit,
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
            switch (try self.input.readAction(&self.rbuf)) {
                .up => return AppAction.up,
                .down => return AppAction.down,
                .select => return AppAction.select,
                .quit => return AppAction.quit,
                .unknown => continue,
                else => continue,
            }
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

    // Tree View to format output
    var tv = tree.TreeView.init(self.allocator);
    defer tv.deinit();

    var out = try Output.init();
    defer out.deinit();

    var inp = Input.init();
    defer inp.deinit();

    // Iterates over fs tree
    var reiterate = true;
    var iter_or_null: ?Manager.Iterator = null;
    defer {
        if (iter_or_null != null) iter_or_null.?.deinit();
    }

    // select (try inp.get)
    while (true) {
        // If manager tree changes in any way
        if (reiterate) {
            defer reiterate = false;
            view.buffer.clearAndFree();
            if (iter_or_null != null) iter_or_null.?.deinit();

            iter_or_null = try self.manager.iterate(-2);
            for (0..vp.rows) |i| {
                const _e = iter_or_null.?.next();
                if (_e == null) {
                    break;
                }

                const e = _e.?;
                try view.buffer.append(e);
                view.last = i;
            }
        }

        try view.update(iter_or_null.?);

        // Print contents of view buffer in range
        try out.printContents(vp.start_row, view, tv);
        std.debug.print("app.run post print position={any}\n", .{try terminal.getCursorPosition()});

        switch (try inp.getAppAction()) {
            .quit => return,
            .down => view.cursor += 1,
            .up => view.cursor -|= 1,
            .select => {
                const item = view.buffer.items[view.cursor].item;
                if (item.hasChildren()) {
                    item.freeChildren(null);
                } else {
                    _ = try item.children();
                }
                reiterate = true;
            },
        }

        try out.draw.clearLinesBelow(vp.start_row);
    }
}

test "test" {}
