const std = @import("std");

const fs = std.fs;
const mem = std.mem;
const os = std.os;

const Manager = @import("../fs/Manager.zig");
const Item = @import("../fs/Item.zig");
const View = @import("./View.zig");
const Viewport = @import("./Viewport.zig");
const TreeView = @import("./TreeView.zig");
const Input = @import("./Input.zig");
const Output = @import("./Output.zig");

viewport: *Viewport,
view: *View,
output: *Output,
input: *Input,
manager: *Manager,

reiterate: bool,
allocator: mem.Allocator,

const Self = @This();

pub fn init(allocator: mem.Allocator, root: []const u8) !Self {
    var viewport = try allocator.create(Viewport);
    viewport.* = try Viewport.init();

    var view = try allocator.create(View);
    view.* = View.init(allocator);

    var output = try allocator.create(Output);
    output.* = try Output.init(allocator);

    var input = try allocator.create(Input);
    input.* = Input.init();

    var manager = try Manager.init(allocator, root);

    return .{
        .viewport = viewport,
        .view = view,
        .output = output,
        .input = input,
        .manager = manager,

        .allocator = allocator,
        .reiterate = true,
    };
}

pub fn deinit(self: *Self) void {
    self.viewport.deinit();
    self.view.deinit();
    self.output.deinit();
    self.input.deinit();
    self.manager.deinit();
}

pub fn preRun(self: *Self) !void {
    try self.viewport.setBounds();
    _ = try self.manager.root.children();
}
