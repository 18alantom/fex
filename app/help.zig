const std = @import("std");
const libc = @cImport({
    @cInclude("unistd.h");
});
const string = @import("../utils/string.zig");
const Writer = std.fs.File.Writer;

const Section = struct {
    title: []const u8,
    items: []const Item,
    description: []const u8 = "",

    // Common keystyle ANSI code
    key_style: []const u8 = "",

    // Coloured description to use if present
    colored_description: []const u8 = "",
};

const Item = struct {
    key: []const u8,
    description: []const u8,
};

const help = [_]Section{
    .{
        .title = "Usage",
        .description = "fex [path] [...flags]",
        .colored_description = "fex [path] [\x1b[36m...flags\x1b[m]",
        .items = &[_]Item{},
    },
    .{
        .title = "Example",
        .description = "fex ~/Desktop --time-type accessed --dotfiles",
        .colored_description = "fex ~/Desktop \x1b[36m--time-type accessed --dotfiles\x1b[m",
        .items = &[_]Item{},
    },
    .{
        .title = "Display Flags",
        .key_style = "\x1b[36m",
        .items = &[_]Item{
            .{
                .key = "--[no-]dotfiles",
                .description = "Show or hide dotfiles (default hidden)",
            },
            .{
                .key = "--[no-]icons",
                .description = "Show or hide icons",
            },
            .{
                .key = "--[no-]size",
                .description = "Show or hide item sizes",
            },
            .{
                .key = "--[no-]time",
                .description = "Show or hide time",
            },
            .{
                .key = "--[no-]perm",
                .description = "Show or hide permission info",
            },
            .{
                .key = "--[no-]link",
                .description = "Show or hide link target",
            },
            .{
                .key = "--[no-]user",
                .description = "Show or hide user name",
            },
            .{
                .key = "--[no-]group",
                .description = "Show or hide group name",
            },
            .{
                .key = "--time-type VALUE",
                .description = "Set which time is displayed [(modified)|accessed|changed]",
            },
            .{
                .key = "--[no-]fullscreen",
                .description = "Enable or disable fullscreen mode",
            },
        },
    },
    .{
        .title = "Search Flags",
        .key_style = "\x1b[36m",
        .items = &[_]Item{
            .{
                .key = "--regular-search",
                .description = "Uses regular search, instead of fuzzy search",
            },
            .{
                .key = "--match-case",
                .description = "Match search query case, instead of ignoring",
            },
        },
    },
    .{
        .title = "Meta",
        .key_style = "\x1b[33m",
        .items = &[_]Item{
            .{
                .key = "--help",
                .description = "Print this help message and quit",
            },
            .{
                .key = "--version",
                .description = "Print the version and quit",
            },
        },
    },
    .{
        .title = "Navigation Controls",
        .key_style = "\x1b[35;1m",
        .items = &[_]Item{
            .{
                .key = "j, <down-arrow>",
                .description = "Cursor down",
            },
            .{
                .key = "k, <up-arrow>",
                .description = "Cursor up",
            },
            .{
                .key = "h, <left-arrow>",
                .description = "Up a dir",
            },
            .{
                .key = "l, <right-arrow>",
                .description = "Down a dir",
            },
            .{
                .key = "gg",
                .description = "Jump to first item",
            },
            .{
                .key = "G",
                .description = "Jump to last item",
            },
            .{
                .key = "{",
                .description = "Jump to prev fold",
            },
            .{
                .key = "}",
                .description = "Jump to next fold",
            },
        },
    },
    .{
        .title = "Action Controls",
        .key_style = "\x1b[32;1m",
        .items = &[_]Item{
            .{
                .key = "<enter>",
                .description = "Toggle directory or open file",
            },
            .{
                .key = "o",
                .description = "Open item under cursor",
            },
            .{
                .key = "E",
                .description = "Expand all directories",
            },
            .{
                .key = "C",
                .description = "Collapse all directories",
            },
            .{
                .key = "R",
                .description = "Change root to item under cursor (if dir)",
            },
            .{
                .key = "/",
                .description = "Toggle search mode",
            },
            .{
                .key = ":",
                .description = "Toggle command mode",
            },
            .{
                .key = "1..9",
                .description = "Expand all directories upto $NUM depth",
            },
            .{
                .key = "<tab>",
                .description = "Toggle item selection under cursor",
            },
            .{
                .key = "q, <ctrl-d>",
                .description = "Quit",
            },
        },
    },
    .{
        .title = "Display Toggle Controls",
        .key_style = "\x1b[34;1m",
        .items = &[_]Item{
            .{
                .key = ".",
                .description = "Toggle dot files display",
            },
            .{
                .key = "I",
                .description = "Toggle item stat info",
            },
            .{
                .key = "ti",
                .description = "Toggle icon display",
            },
            .{
                .key = "tp",
                .description = "Toggle permission info display",
            },
            .{
                .key = "ts",
                .description = "Toggle size display",
            },
            .{
                .key = "tt",
                .description = "Toggle time display",
            },
            .{
                .key = "tl",
                .description = "Toggle link target display",
            },
            .{
                .key = "tu",
                .description = "Toggle user name display",
            },
            .{
                .key = "tg",
                .description = "Toggle group name display",
            },
            .{
                .key = "tm",
                .description = "Display modified time",
            },
            .{
                .key = "ta",
                .description = "Display accessed time",
            },
            .{
                .key = "tc",
                .description = "Display changed time",
            },
        },
    },
    .{
        .title = "Sort Controls",
        .key_style = "\x1b[36;1m",
        .items = &[_]Item{
            .{
                .key = "sn",
                .description = "Sort in ascending order by name",
            },
            .{
                .key = "ss",
                .description = "Sort in ascending order by size",
            },
            .{
                .key = "st",
                .description = "Sort in ascending order by displayed time",
            },
            .{
                .key = "sdn",
                .description = "Sort in descending order by name",
            },
            .{
                .key = "sds",
                .description = "Sort in descending order by size",
            },
            .{
                .key = "sdt",
                .description = "Sort in descending order by displayed time",
            },
        },
    },
    .{
        .title = "File System Controls",
        .key_style = "\x1b[1;38;5;147m",
        .items = &[_]Item{
            .{
                .key = "cd",
                .description = "Quit and change directory to item under cursor (needs zsh-widget)",
            },
        },
    },
    .{
        .title = "Search Mode Controls",
        .key_style = "\x1b[1;33m",
        .items = &[_]Item{
            .{
                .key = "<escape>",
                .description = "Quit search, restore cursor position",
            },
            .{
                .key = "<enter>",
                .description = "Quit search",
            },
        },
    },
    .{
        .title = "Command Mode Controls",
        .key_style = "\x1b[1;38;5;216m",
        .items = &[_]Item{
            .{
                .key = "<escape>",
                .description = "Quit command mode",
            },
            .{
                .key = "<enter>",
                .description = "Quit fex, execute command with selected items or item",
            },
        },
    },
};

pub fn printHelp() !void {
    const writer = std.io.getStdOut().writer();
    const is_terminal = libc.isatty(std.posix.STDOUT_FILENO) >= 1;

    for (help) |section| {
        try printTitle(section, is_terminal, writer);
        try printDescription(section, is_terminal, writer);
        try printItems(section, is_terminal, writer);
    }

    try printFooter(is_terminal, writer);
}

fn printTitle(section: Section, is_terminal: bool, writer: Writer) !void {
    if (is_terminal) {
        try writer.print("\x1b[1;4m{s}\x1b[m\n", .{section.title});
    } else {
        try writer.print("{s}\n", .{section.title});
    }
}

fn printDescription(section: Section, is_terminal: bool, writer: Writer) !void {
    const description = if (is_terminal and section.colored_description.len > 0)
        section.colored_description
    else
        section.description;
    if (description.len > 0) {
        try writer.print("    {s}\n", .{description});
    }
}

fn printItems(section: Section, is_terminal: bool, writer: Writer) !void {
    var buf: [128]u8 = undefined;
    for (section.items) |item| {
        const key = string.rpad(item.key, 24, ' ', &buf);
        if (is_terminal and section.key_style.len > 0) {
            try writer.print("    {s}{s}\x1b[m {s}\n", .{ section.key_style, key, item.description });
        } else if (is_terminal and section.key_style.len == 0) {
            try writer.print("    \x1b[32m{s}\x1b[m {s}\n", .{ key, item.description });
        } else {
            try writer.print("    {s} {s}\n", .{ key, item.description });
        }
    }

    try writer.print("\n", .{});
}

fn printFooter(is_terminal: bool, writer: Writer) !void {
    const url = "https://github.com/18alantom/fex#setup";
    if (is_terminal) {
        try writer.print("Learn about setup: \x1b[34m{s}\x1b[m\n", .{url});
    } else {
        try writer.print("Learn about setup: {s}\n", .{url});
    }
}
