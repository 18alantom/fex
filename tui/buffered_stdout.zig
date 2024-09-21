const std = @import("std");

const io = std.io;
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const FileWriter = fs.File.Writer;

pub fn BufferedStdOut(comptime buffer_size: usize) type {
    return struct {
        writer: FileWriter,
        buf: [buffer_size]u8 = undefined,
        fbuf: [buffer_size]u8 = undefined,
        end: usize = 0,
        use_buffer: bool = false,

        // Sequences for Synchronized Output, these depend on terminal support
        // afaik the unofficial spec (DCS) if primarily supported by iTerm2.
        //
        // The CSI based spec doesn't seem to work (as expected) with iTerm2.
        // CSI may be used without compatibility check (?) as it fails silently.
        //
        // The compatibility check does not work on macOS Terminal.
        //
        // refs:
        // - DCS: https://gitlab.com/gnachman/iterm2/-/wikis/synchronized-updates-spec
        // - CSI: https://gist.github.com/christianparpart/d8a62cc1ab659194337d73e399004036
        use_csi_sync: bool = false,
        use_dcs_sync: bool = false,

        pub const Writer = io.Writer(
            *Self,
            FileWriter.Error,
            write,
        );

        const Self = @This();

        pub fn init() Self {
            return .{
                .writer = io.getStdErr().writer(),
            };
        }

        pub fn flush(self: *Self) !void {
            if (self.end == 0) return;
            if (self.use_csi_sync or self.use_dcs_sync) {
                self.endSync();
            }
            try self.writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub fn buffered(self: *Self) void {
            self.use_buffer = true;
            if (self.use_csi_sync or self.use_dcs_sync) {
                self.beginSync();
            }
        }

        fn beginSync(self: *Self) void {
            const seq = if (self.use_csi_sync)
                "\x1b[?2026h"
            else if (self.use_dcs_sync)
                "\x1bP=1s\x1b\\"
            else
                "";

            if (self.end + seq.len > self.buf.len) return;
            self.copy(seq);
        }

        fn endSync(self: *Self) void {
            const seq = if (self.use_csi_sync)
                "\x1b[?2026l"
            else if (self.use_dcs_sync)
                "\x1bP=2s\x1b\\"
            else
                "";

            if (self.end + seq.len > self.buf.len) return;
            self.copy(seq);
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

        fn writebf(self: *Self, bytes: []const u8) !usize {
            if (self.end + bytes.len > self.buf.len) {
                try self.flush();
                if (bytes.len > self.buf.len)
                    return self.writer.write(bytes);
            }

            self.copy(bytes);
            return bytes.len;
        }

        fn copy(self: *Self, bytes: []const u8) void {
            const new_end = self.end + bytes.len;
            @memcpy(self.buf[self.end..new_end], bytes);
            self.end = new_end;
        }

        fn writefl(self: *Self, bytes: []const u8) !usize {
            return try self.writer.write(bytes);
        }

        pub fn print(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            if (self.use_buffer) {
                return try self.printbf(bytes, args);
            }

            return try self.printfl(bytes, args);
        }

        fn printbf(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            return try self._print(bytes, args, true);
        }

        fn printfl(self: *Self, comptime bytes: []const u8, args: anytype) !usize {
            return try self._print(bytes, args, false);
        }

        fn _print(self: *Self, comptime bytes: []const u8, args: anytype, is_use_buffer: bool) !usize {
            var fbs = std.io.fixedBufferStream(&self.fbuf);
            try fmt.format(fbs.writer(), bytes, args);
            const fbytes = fbs.getWritten();
            if (is_use_buffer) {
                return try self.writebf(fbytes);
            } else {
                return try self.writefl(fbytes);
            }
        }
    };
}
