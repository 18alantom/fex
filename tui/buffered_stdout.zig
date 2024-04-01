const std = @import("std");

const io = std.io;
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const FileWriter = fs.File.Writer;

pub fn BufferedStdOut(comptime buffer_size: usize) type {
    return struct {
        unbuffered_writer: FileWriter,
        buf: [buffer_size]u8 = undefined,
        fbuf: [buffer_size]u8 = undefined,
        end: usize = 0,
        buffered: bool = false,

        pub const Writer = io.Writer(
            *Self,
            FileWriter.Error,
            write,
        );

        const Self = @This();

        pub fn init() Self {
            return .{
                .unbuffered_writer = io.getStdOut().writer(),
            };
        }

        pub fn flush(self: *Self) !void {
            try self.unbuffered_writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub fn bufferOutput(self: *Self) void {
            self.buffered = true;
        }

        pub fn flushAndUnbufferOutput(self: *Self) !void {
            try self.flush();
            self.buffered = false;
        }

        pub fn write(self: *Self, bytes: []const u8) !usize {
            if (self.buffered) {
                return try self.writebf(bytes);
            }

            return try self.writefl(bytes);
        }

        pub fn writebf(self: *Self, bytes: []const u8) !usize {
            if (self.end + bytes.len > self.buf.len) {
                try self.flush();
                if (bytes.len > self.buf.len)
                    return self.unbuffered_writer.write(bytes);
            }

            const new_end = self.end + bytes.len;
            @memcpy(self.buf[self.end..new_end], bytes);
            self.end = new_end;
            return bytes.len;
        }

        pub fn writefl(self: *Self, bytes: []const u8) !usize {
            return try self.unbuffered_writer.write(bytes);
        }

        pub fn print(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            if (self.buffered) {
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

        pub fn _print(self: *Self, comptime bytes: []const u8, args: anytype, is_buffered: bool) !usize {
            var fbs = std.io.fixedBufferStream(&self.fbuf);
            try fmt.format(fbs.writer(), bytes, args);
            var fbytes = fbs.getWritten();
            if (is_buffered) {
                return try self.writebf(bytes);
            } else {
                return try self.write(fbytes);
            }
        }
    };
}
