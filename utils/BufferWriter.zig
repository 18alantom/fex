const std = @import("std");

const Self = @This();

buffer: []u8,
total: usize = 0,

pub fn init(buf: []u8) Self {
    return .{ .buffer = buf };
}

pub fn writeByte(self: *Self, byte: u8) !void {
    if (self.buffer.len <= self.total) return error.NoSpaceLeft;

    self.buffer[self.total] = byte;
    self.total += 1;
}

pub fn writeBytes(self: *Self, bytes: []u8) !void {
    const end = self.total + bytes.len;
    if (self.buffer.len <= end) return error.NoSpaceLeft;
    @memcpy(self.buffer[self.total..end], bytes);
    self.total += bytes.len;
}

pub fn write(self: *Self, comptime bytes: []const u8) !void {
    return try self.print(bytes, .{});
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    const slc = try std.fmt.bufPrint(self.buffer[self.total..], fmt, args);
    self.total += slc.len;
}

pub fn string(self: *Self) []const u8 {
    return self.buffer[0..self.total];
}

pub fn clear(self: *Self) void {
    self.total = 0;
}
