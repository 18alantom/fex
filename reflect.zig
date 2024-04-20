const std = @import("std");
const utils = @import("./utils.zig");
const builtin = std.builtin;

pub fn typeInfo(comptime T: type, indent: usize) void {
    if (indent == 0) std.debug.print("\x1b[31m{any}\x1b[m\n", .{T});
    const info = @typeInfo(T);
    switch (info) {
        .Struct => printStruct(info.Struct, indent + 1),
        else => return,
    }
}

fn printStruct(comptime S: builtin.Type.Struct, indent: usize) void {
    var buf: [256]u8 = undefined;
    const spc = utils.repeat(&buf, "   ", indent);
    const spc2 = utils.repeat(buf[spc.len..], "   ", indent + 1);

    // Fields
    if (S.fields.len > 0) std.debug.print("{s}\x1b[36mfields\x1b[m:\n", .{spc});
    inline for (S.fields) |field| {
        // name and type
        std.debug.print("{s}.{s} \x1b[34m{any}\x1b[m, ", .{ spc2, field.name, field.type });

        // less important field meta
        std.debug.print("\x1b[2malignment: {any}, ", .{field.alignment});
        std.debug.print("is_comptime: {any}, ", .{field.is_comptime});
        std.debug.print("default_value: {any}\x1b[m", .{field.default_value});
        std.debug.print("\n", .{});
        typeInfo(field.type, indent + 1);
    }

    // Declarations
    if (S.decls.len > 0) std.debug.print("{s}\x1b[36mdecls\x1b[m:\n", .{spc});
    inline for (S.decls) |decl| {
        std.debug.print("{s}\x1b[35m{s}\x1b[m\n", .{ spc2, decl.name });
    }

    // less important struct meta
    std.debug.print("{s}\x1b[2mlayout: {any}, ", .{ spc, S.layout });
    std.debug.print("is_tuple: {any}, ", .{S.is_tuple});
    std.debug.print("backing_integer: {any}\x1b[m\n", .{S.backing_integer});
}
