const std = @import("std");
const print = std.debug.print;
const unicode = std.unicode;
const io = std.io;

/// Breaks input into bytes and unicode codepoints
pub fn main() !void {
    const reader = io.getStdIn().reader();

    var rbuf: [512]u8 = undefined;
    while (true) {
        print("\x1b[1;35m>\x1b[m ", .{});
        const rlen = try reader.read(&rbuf);
        if (rlen <= 2 and rbuf[0] == 'q') {
            break;
        }

        inspect(rbuf[0..rlen]);
    }
}

pub fn inspect(str: []const u8) void {
    print("\n\x1b[1;34m", .{});
    printChars(str);
    printBytes(str);
    print("\x1b[m\n", .{});

    print("\x1b[1;36m", .{});
    printCodePoints(str, true) catch {};
    printCodePoints(str, false) catch {};
    print("\x1b[m\n", .{});
}

pub fn printChars(str: []const u8) void {
    for (str) |b| {
        printByte(b);
    }
    print("\n", .{});
}

fn printBytes(str: []const u8) void {
    for (str) |b| {
        print("{d:3} ", .{b});
    }
    print("\n", .{});
}

pub fn printCodePoints(str: []const u8, print_str: bool) !void {
    var i: usize = 0;
    while (true) {
        if (i >= str.len) {
            break;
        }

        const b = str[i];
        const cp_len: u3 = switch (b) {
            0b0000_0000...0b0111_1111 => 1,
            0b1100_0000...0b1101_1111 => 2,
            0b1110_0000...0b1110_1111 => 3,
            0b1111_0000...0b1111_0111 => 4,
            else => unreachable,
        };

        const cp_slc = str[i .. i + cp_len];
        i += cp_len;
        if (cp_len == 1) {
            if (print_str) {
                printByte(cp_slc[0]);
            } else {
                print("{d:3} ", .{cp_slc[0]});
            }
        } else {
            if (print_str) {
                print("{s:5} ", .{cp_slc});
            } else {
                print("{x:5} ", .{try unicode.utf8Decode(cp_slc)});
            }
        }
    }

    print("\n", .{});
}

fn printByte(b: u8) void {
    switch (b) {
        0 => print("NUL ", .{}),
        1 => print("SOH ", .{}),
        2 => print("STX ", .{}),
        3 => print("ETX ", .{}),
        4 => print("EOT ", .{}),
        5 => print("ENQ ", .{}),
        6 => print("ACK ", .{}),
        7 => print("BEL ", .{}),
        8 => print(" BS ", .{}),
        9 => print(" HT ", .{}),
        10 => print(" LF ", .{}),
        11 => print(" VT ", .{}),
        12 => print(" FF ", .{}),
        13 => print(" CR ", .{}),
        14 => print(" SO ", .{}),
        15 => print(" SI ", .{}),
        16 => print("DLE ", .{}),
        17 => print("DC1 ", .{}),
        18 => print("DC2 ", .{}),
        19 => print("DC3 ", .{}),
        20 => print("DC4 ", .{}),
        21 => print("NAK ", .{}),
        22 => print("SYN ", .{}),
        23 => print("ETB ", .{}),
        24 => print("CAN ", .{}),
        25 => print(" EM ", .{}),
        26 => print("SUB ", .{}),
        27 => print("ESC ", .{}),
        28 => print(" FS ", .{}),
        29 => print(" GS ", .{}),
        30 => print(" RS ", .{}),
        31 => print(" US ", .{}),
        32 => print("SPC ", .{}),
        else => print("{c:3} ", .{b}),
    }
}
