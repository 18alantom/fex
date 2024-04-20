const builtin = @import("builtin");
const std = @import("std");
const libc = @cImport({
    @cInclude("sys/stat.h");
});

const fs = std.fs;
const mem = std.mem;
const os = std.os;

mode: u16,
size: i64,

// Modified
mtime_sec: isize,
mtime_nsec: isize,

// Accessed
atime_sec: isize,
atime_nsec: isize,

// Last Status Change
ctime_sec: isize,
ctime_nsec: isize,

const Self = @This();

pub fn stat(abspath: []const u8) !Self {

    // To sentinel terminated pointer
    var abspath_w: [*:0]const u8 = @ptrCast(abspath.ptr);

    var statbuf: libc.struct_stat = undefined;
    if (libc.lstat(abspath_w, &statbuf) != 0) {
        return error.StatError;
    }

    switch (builtin.target.os.tag) {
        .macos => return .{
            .mode = statbuf.st_mode,
            .size = statbuf.st_size,
            // mtime
            .mtime_sec = statbuf.st_mtimespec.tv_sec,
            .mtime_nsec = statbuf.st_mtimespec.tv_nsec,
            // atime
            .atime_sec = statbuf.st_atimespec.tv_sec,
            .atime_nsec = statbuf.st_atimespec.tv_nsec,
            // ctime
            .ctime_sec = statbuf.st_ctimespec.tv_sec,
            .ctime_nsec = statbuf.st_ctimespec.tv_nsec,
        },
        .linux => return .{
            .mode = statbuf.st_mode,
            .size = statbuf.st_size,
            // mtime
            .mtime_sec = statbuf.st_mtim.tv_sec,
            .mtime_nsec = statbuf.st_mtim.tv_nsec,
            // atime
            .atime_sec = statbuf.st_atim.tv_sec,
            .atime_nsec = statbuf.st_atim.tv_nsec,
            // ctime
            .ctime_sec = statbuf.st_ctim.tv_sec,
            .ctime_nsec = statbuf.st_ctim.tv_nsec,
        },
        else => return error.NotImplemented,
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
    return (libc.S_IXUSR & self.mode) > 0;
}

pub fn hasUserWrite(self: *const Self) bool {
    return (libc.S_IWUSR & self.mode) > 0;
}

pub fn hasUserRead(self: *const Self) bool {
    return (libc.S_IRUSR & self.mode) > 0;
}

// Group permissions
pub fn hasGroupExec(self: *const Self) bool {
    return (libc.S_IXGRP & self.mode) > 0;
}

pub fn hasGroupWrite(self: *const Self) bool {
    return (libc.S_IWGRP & self.mode) > 0;
}

pub fn hasGroupRead(self: *const Self) bool {
    return (libc.S_IRGRP & self.mode) > 0;
}

// Other permissions
pub fn hasOtherExec(self: *const Self) bool {
    return (libc.S_IXOTH & self.mode) > 0;
}

pub fn hasOtherWrite(self: *const Self) bool {
    return (libc.S_IWOTH & self.mode) > 0;
}

pub fn hasOtherRead(self: *const Self) bool {
    return (libc.S_IROTH & self.mode) > 0;
}
