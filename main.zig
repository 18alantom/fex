const std = @import("std");
const utils = @import("utils.zig");
const Tui = @import("Tui.zig");
const App = @import("App.zig");

const fs = std.fs;
const os = std.os;
const fmt = std.fmt;
const time = std.time;
const mem = std.mem;

const allocator = std.heap.page_allocator;

const print = std.debug.print;

pub fn main() !void {
    var tui = try Tui.init(
        std.heap.page_allocator,
        .{
            .render = App.render,
            .process = App.process,
        },
    );
    try tui.loop();
}
