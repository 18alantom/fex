const builtin = @import("builtin");
const std = @import("std");
const utils = @import("../utils.zig");
const linux = std.os.linux;

// Due to lazy eval not included if linux
const libc = @cImport({
    @cInclude("sys/stat.h");
});

const is_linux = builtin.os.tag == .linux;
const Mode = if (is_linux)
    utils.FieldType(linux.Stat, "mode") // u32
else
    utils.FieldType(libc.struct_stat, "st_mode"); // c_int, i32

const fs = std.fs;
const mem = std.mem;

mode: Mode,
size: i64,

// Seconds since epoch
mtime_sec: isize, // Modified
atime_sec: isize, // Accessed
ctime_sec: isize, // Last Status Change

const Self = @This();

pub const TimeType = enum { modified, changed, accessed };

pub fn stat(abspath: []const u8) !Self {
    // To sentinel terminated pointer
    const abspath_w: [*:0]const u8 = @ptrCast(abspath.ptr);

    // if linux, can use Zig impl of lstat
    if (is_linux) {
        var statbuf: linux.Stat = undefined;
        if (linux.lstat(abspath_w, &statbuf) != 0) {
            return error.StatError;
        }

        return .{
            .mode = statbuf.mode,
            .size = statbuf.size,
            .mtime_sec = statbuf.mtim.tv_sec,
            .atime_sec = statbuf.atim.tv_sec,
            .ctime_sec = statbuf.ctim.tv_sec,
        };
    }

    // if not linux, defaul to libc impl of lstat
    else {
        var statbuf: libc.struct_stat = undefined;
        if (libc.lstat(abspath_w, &statbuf) != 0) {
            return error.StatError;
        }

        return .{
            .mode = statbuf.st_mode,
            .size = statbuf.st_size,
            .mtime_sec = statbuf.st_mtimespec.tv_sec,
            .atime_sec = statbuf.st_atimespec.tv_sec,
            .ctime_sec = statbuf.st_ctimespec.tv_sec,
        };
    }
}

// File type checks
// ref: https://www.gnu.org/software/libc/manual/html_node/Testing-File-Type.html
pub fn isExec(self: *const Self) bool {
    return self.hasUserExec();
}

pub fn isReg(self: *const Self) bool {
    return libc.S_ISREG(self.mode);
}

pub fn isDir(self: *const Self) bool {
    return libc.S_ISDIR(self.mode);
}

pub fn isLink(self: *const Self) bool {
    return libc.S_ISLNK(self.mode);
}

pub fn isBlock(self: *const Self) bool {
    return libc.S_ISBLK(self.mode);
}

pub fn isFIFO(self: *const Self) bool {
    return libc.S_ISFIFO(self.mode);
}

pub fn isChr(self: *const Self) bool {
    return libc.S_ISCHR(self.mode);
}

pub fn isSock(self: *const Self) bool {
    return libc.S_ISSOCK(self.mode);
}

// User permissions
pub fn hasUserExec(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IXUSR else libc.S_IXUSR;
    return (mask & self.mode) > 0;
}

pub fn hasUserWrite(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IWUSR else libc.S_IWUSR;
    return (mask & self.mode) > 0;
}

pub fn hasUserRead(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IRUSR else libc.S_IRUSR;
    return (mask & self.mode) > 0;
}

// Group permissions
pub fn hasGroupExec(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IXGRP else libc.S_IXGRP;
    return (mask & self.mode) > 0;
}

pub fn hasGroupWrite(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IWGRP else libc.S_IWGRP;
    return (mask & self.mode) > 0;
}

pub fn hasGroupRead(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IRGRP else libc.S_IRGRP;
    return (mask & self.mode) > 0;
}

// Other permissions
pub fn hasOtherExec(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IXOTH else libc.S_IXOTH;
    return (mask & self.mode) > 0;
}

pub fn hasOtherWrite(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IWOTH else libc.S_IWOTH;
    return (mask & self.mode) > 0;
}

pub fn hasOtherRead(self: *const Self) bool {
    const mask = if (is_linux) linux.S.IROTH else libc.S_IROTH;
    return (mask & self.mode) > 0;
}
