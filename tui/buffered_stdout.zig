const std = @import("std");

const io = std.io;
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const FileWriter = fs.File.Writer;

pub fn BufferedStdOut(comptime buffer_size: usize) type {
    return struct {
        unuse_buffer_writer: FileWriter,
        buf: [buffer_size]u8 = undefined,
        fbuf: [buffer_size]u8 = undefined,
        end: usize = 0,
        use_buffer: bool = false,

        pub const Writer = io.Writer(
            *Self,
            FileWriter.Error,
            write,
        );

        const Self = @This();

        pub fn init() Self {
            return .{
                .unuse_buffer_writer = io.getStdOut().writer(),
            };
        }

        pub fn flush(self: *Self) !void {
            if (self.end == 0) return;
            try self.unuse_buffer_writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub fn buffered(self: *Self) void {
            self.use_buffer = true;
        }

        pub fn unbuffered(self: *Self) void {
            self.use_buffer = false;
        }

        pub fn write(self: *Self, bytes: []const u8) !usize {
            if (self.use_buffer) {
                return try self.writebf(bytes);
            }

            return try self.writefl(bytes);
        }

        pub fn writebf(self: *Self, bytes: []const u8) !usize {
            if (self.end + bytes.len > self.buf.len) {
                try self.flush();
                if (bytes.len > self.buf.len)
                    return self.unuse_buffer_writer.write(bytes);
            }

            const new_end = self.end + bytes.len;
            @memcpy(self.buf[self.end..new_end], bytes);
            self.end = new_end;
            return bytes.len;
        }

        pub fn writefl(self: *Self, bytes: []const u8) !usize {
            return try self.unuse_buffer_writer.write(bytes);
        }

        pub fn print(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            if (self.use_buffer) {
                return try self.printbf(bytes, args);
            }

            return try self.printfl(bytes, args);
        }

        pub fn printbf(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            return try self._print(bytes, args, true);
        }

        pub fn printfl(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            return try self._print(bytes, args, false);
        }

        pub fn _print(self: *Self, comptime bytes: []const u8, args: anytype, is_use_buffer: bool) !usize {
            var fbs = std.io.fixedBufferStream(&self.fbuf);
            try fmt.format(fbs.writer(), bytes, args);
            var fbytes = fbs.getWritten();
            if (is_use_buffer) {
                return try self.writebf(fbytes);
            } else {
                return try self.writefl(fbytes);
            }
        }
    };
}
