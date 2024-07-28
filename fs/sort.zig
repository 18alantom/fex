const std = @import("std");
const Item = @import("./Item.zig");

pub const SortType = enum {
    size,
    name,

    // Time
    modified,
    changed,
    accessed,
};

const Context = struct {
    how: SortType,
    asc: bool,
};

const Comparator = struct {
    pub fn ltf(context: Context, lhs: *Item, rhs: *Item) bool {
        switch (context.how) {
            .name => return name(context, lhs, rhs),
            .size => return size(context, lhs, rhs),
            .modified => return time(context, lhs, rhs),
            .accessed => return time(context, lhs, rhs),
            .changed => return time(context, lhs, rhs),
        }
    }

    fn name(context: Context, lhs: *Item, rhs: *Item) bool {
        const a = lhs.name();
        const b = rhs.name();
        const len = if (a.len < b.len)
            a.len
        else
            b.len;

        for (0..len) |i| {
            const va = a[i];
            const vb = b[i];
            if (va == vb) {
                continue;
            }

            if (context.asc) {
                return va < vb;
            }

            return va > vb;
        }

        if (context.asc) {
            return a.len < b.len;
        }

        return a.len > b.len;
    }

    fn size(context: Context, lhs: *Item, rhs: *Item) bool {
        const a = lhs.size() catch 0;
        const b = rhs.size() catch 0;

        if (context.asc) {
            return a < b;
        }

        return a > b;
    }

    fn time(context: Context, lhs: *Item, rhs: *Item) bool {
        const a = getTime(lhs, context.how);
        const b = getTime(rhs, context.how);

        if (context.asc) {
            return a < b;
        }

        return a > b;
    }
};

pub fn sort(
    items: *Item.ItemList,
    how: SortType,
    asc: bool,
) void {
    const context = Context{ .how = how, .asc = asc };
    std.mem.sort(
        *Item,
        items.items,
        context,
        Comparator.ltf,
    );
}

fn getTime(item: *Item, how: SortType) isize {
    if (how == .modified) {
        const s = item.stat() catch return 0;
        return s.mtime_sec;
    }

    if (how == .accessed) {
        const s = item.stat() catch return 0;
        return s.atime_sec;
    }

    if (how == .changed) {
        const s = item.stat() catch return 0;
        return s.ctime_sec;
    }

    return 0;
}
