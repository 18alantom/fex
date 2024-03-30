const Manager = @import("../fs/Manager.zig");
const Entry = Manager.Iterator.Entry;

pub fn getIcon(entry: Entry) ![]const u8 {
    const item = entry.item;

    if (try item.isDir()) {
        return if (item.hasChildren()) "\u{f07c}" else "\u{f07b}";
    }

    return "\u{f15b}";
}
