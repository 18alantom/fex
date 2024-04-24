const std = @import("std");
const utils = @import("../utils.zig");

const Manager = @import("../fs/Manager.zig");

const path = std.fs.path;
const mem = std.mem;

const Entry = Manager.Iterator.Entry;
const eql = utils.eql;

pub fn getIcon(entry: Entry) ![]const u8 {
    const item = entry.item;
    var ext = path.extension(item.abspath());
    if (ext.len == 0) {
        ext = item.name();
    }

    // Python
    if (eql(ext, ".py")) return icons.python;
    if (eql(ext, ".pyi")) return icons.python;
    if (eql(ext, ".pyc")) return icons.python;
    if (eql(ext, ".ipynb")) return icons.python;

    // JS and Frontend
    if (eql(ext, ".js")) return icons.javascript;
    if (eql(ext, ".mjs")) return icons.javascript;
    if (eql(ext, ".ejs")) return icons.javascript;
    if (eql(ext, ".cjs")) return icons.javascript;
    if (eql(ext, ".jsx")) return icons.javascript;
    if (eql(ext, ".ts")) return icons.typescript;
    if (eql(ext, ".tsx")) return icons.typescript;
    if (eql(ext, ".css")) return icons.css3;
    if (eql(ext, ".sass")) return icons.sass;
    if (eql(ext, ".scss")) return icons.sass;
    if (eql(ext, ".html")) return icons.html5;

    // C
    if (eql(ext, ".c")) return icons.c;
    if (eql(ext, ".h")) return icons.c;

    // C++
    if (eql(ext, ".cpp")) return icons.cpp;
    if (eql(ext, ".hpp")) return icons.cpp;
    if (eql(ext, ".c++")) return icons.cpp;
    if (eql(ext, ".h++")) return icons.cpp;

    // BEAM
    if (eql(ext, ".ex")) return icons.elixir;
    if (eql(ext, ".exs")) return icons.elixir;
    if (eql(ext, ".erl")) return icons.erlang;
    if (eql(ext, ".hrl")) return icons.erlang;

    // Java
    if (eql(ext, ".java")) return icons.java;
    if (eql(ext, ".class")) return icons.java;
    if (eql(ext, ".jar")) return icons.java;
    if (eql(ext, ".jmod")) return icons.java;

    // Clojure
    if (eql(ext, ".clj")) return icons.clojure;
    if (eql(ext, ".cljs")) return icons.clojure;
    if (eql(ext, ".cljr")) return icons.clojure;
    if (eql(ext, ".cljc")) return icons.clojure;
    if (eql(ext, ".edn")) return icons.clojure;

    // Kotlin
    if (eql(ext, ".kt")) return icons.kotlin;
    if (eql(ext, ".kts")) return icons.kotlin;
    if (eql(ext, ".kexe")) return icons.kotlin;
    if (eql(ext, ".klib")) return icons.kotlin;

    // Scala
    if (eql(ext, ".scala")) return icons.scala;
    if (eql(ext, ".sc")) return icons.scala;

    // Haskell
    if (eql(ext, ".hs")) return icons.haskell;
    if (eql(ext, ".lhs")) return icons.haskell;

    // Text
    if (eql(ext, ".md")) return icons.markdown;
    if (eql(ext, ".txt")) return icons.txt;

    // Vim
    if (eql(ext, ".viminfo")) return icons.vim;
    if (eql(ext, ".vimrc")) return icons.vim;
    if (eql(ext, ".vim")) return icons.vim;

    // Git
    if (eql(ext, ".git")) return icons.git;
    if (eql(ext, ".gitignore")) return icons.git;

    // Perl
    if (eql(ext, ".pl")) return icons.perl;
    if (eql(ext, ".plx")) return icons.perl;

    // Font
    if (eql(ext, ".woff")) return icons.font;
    if (eql(ext, ".otf")) return icons.font;
    if (eql(ext, ".ttf")) return icons.font;

    // Misc
    if (eql(ext, ".rs")) return icons.rust;
    if (eql(ext, ".rb")) return icons.ruby;
    if (eql(ext, ".cr")) return icons.crystal;
    if (eql(ext, ".asm")) return icons.assembly;
    if (eql(ext, ".zig")) return icons.zig;
    if (eql(ext, ".go")) return icons.go;
    if (eql(ext, ".elm")) return icons.elm;
    if (eql(ext, ".php")) return icons.php;
    if (eql(ext, ".sqlite")) return icons.sqlite;

    if (try item.isDir()) {
        return if (item.hasChildren()) icons.folder_open else icons.folder;
    }

    // TODO: Add fonts for audio, video, etc
    return icons.file;
}

// Unicode values sourced from the Nerd-fonts cheatsheet.
// https://www.nerdfonts.com/cheat-sheet
const icons = .{
    .assembly = "\u{e6ab}",
    .c = "\u{e61e}",
    .cpp = "\u{e61d}",
    .crystal = "\u{e62f}",
    .default = "\u{e612}",
    .elixir = "\u{e62d}",
    .elm = "\u{e62c}",
    .erlang = "\u{e7b1}",
    .folder = "\u{e5ff}",
    .folder_open = "\u{e5fe}",
    .go = "\u{e626}",
    .kotlin = "\u{e634}",
    .neovim = "\u{e6ae}",
    .play_arrow = "\u{e602}",
    .puppet = "\u{e631}",
    .purescript = "\u{e630}",
    .vim = "\u{e62b}",
    .windows = "\u{e62a}",
    .android = "\u{e70e}",
    .apple = "\u{e711}",
    .asterisk = "\u{e7ac}",
    .atom = "\u{e764}",
    .bitbucket = "\u{e703}",
    .bower = "\u{e74d}",
    .chrome = "\u{e743}",
    .clojure = "\u{e768}",
    .code = "\u{e796}",
    .codepen = "\u{e716}",
    .compass = "\u{e761}",
    .css3 = "\u{e749}",
    .dart = "\u{e798}",
    .database = "\u{e706}",
    .debian = "\u{e77d}",
    .docker = "\u{e7b0}",
    .dropbox = "\u{e707}",
    .drupal = "\u{e742}",
    .firebase = "\u{e787}",
    .firefox = "\u{e745}",
    .git = "\u{f1d3}",
    .grunt = "\u{e74c}",
    .gulp = "\u{e763}",
    .haskell = "\u{e777}",
    .html5 = "\u{e736}",
    .java = "\u{e66d}",
    .javascript = "\u{e74e}",
    .joomla = "\u{e741}",
    .less = "\u{e758}",
    .linux = "\u{e712}",
    .markdown = "\u{e73e}",
    .mysql = "\u{e704}",
    .npm = "\u{e71e}",
    .opera = "\u{e746}",
    .perl = "\u{e769}",
    .photoshop = "\u{e7b8}",
    .php = "\u{e73d}",
    .prolog = "\u{e7a1}",
    .python = "\u{e73c}",
    .react = "\u{e7ba}",
    .redhat = "\u{e7bb}",
    .ruby = "\u{e739}",
    .rust = "\u{e7a8}",
    .safari = "\u{e748}",
    .sass = "\u{e74b}",
    .scala = "\u{e737}",
    .stylus = "\u{e759}",
    .sublime = "\u{e7aa}",
    .swift = "\u{e755}",
    .sqlite = "\u{e7c4}",
    .terminal = "\u{e795}",
    .trello = "\u{e75a}",
    .toml = "\u{e6b2}",
    .typescript = "\u{e628}",
    .txt = "\u{f15c}",
    .ubuntu = "\u{e73a}",
    .w3c = "\u{e76c}",
    .wordpress = "\u{e70b}",
    .yahoo = "\u{e715}",
    .archive = "\u{f187}",
    .arrow_down = "\u{f063}",
    .arrow_left = "\u{f060}",
    .arrow_right = "\u{f061}",
    .arrow_up = "\u{f062}",
    .bath = "\u{f2cd}",
    .bed = "\u{f236}",
    .bell = "\u{f0f3}",
    .bell_slash = "\u{f1f6}",
    .bold = "\u{f032}",
    .book = "\u{f02d}",
    .bookmark = "\u{f02e}",
    .briefcase = "\u{f0b1}",
    .bug = "\u{f188}",
    .calendar = "\u{f073}",
    .file = "\u{f15b}",
    .filter = "\u{f0b0}",
    .font = "\u{f031}",
    .gear = "\u{f013}",
    .gift = "\u{f06b}",
    .gitlab = "\u{f296}",
    .glass = "\u{f000}",
    .globe = "\u{f0ac}",
    .grav = "\u{f2d6}",
    .heart = "\u{f004}",
    .history = "\u{f1da}",
    .hourglass = "\u{f254}",
    .id_badge = "\u{f2c1}",
    .id_card = "\u{f2c2}",
    .image = "\u{f03e}",
    .imdb = "\u{f2d8}",
    .inbox = "\u{f01c}",
    .info = "\u{f129}",
    .italic = "\u{f033}",
    .key = "\u{f084}",
    .link = "\u{f0c1}",
    .lock = "\u{f023}",
    .mortar_board = "\u{f19d}",
    .paperclip = "\u{f0c6}",
    .paste = "\u{f0ea}",
    .pencil = "\u{f040}",
    .play = "\u{f04b}",
    .plug = "\u{f1e6}",
    .plus = "\u{f067}",
    .plus_circle = "\u{f055}",
    .question = "\u{f128}",
    .reply = "\u{f112}",
    .rocket = "\u{f135}",
    .rss = "\u{f09e}",
    .search = "\u{f002}",
    .server = "\u{f233}",
    .share = "\u{f064}",
    .shield = "\u{f132}",
    .sign_in = "\u{f090}",
    .sign_out = "\u{f08b}",
    .sliders = "\u{f1de}",
    .sort_asc = "\u{f0de}",
    .sort_desc = "\u{f0dd}",
    .square = "\u{f0c8}",
    .star = "\u{f005}",
    .stop = "\u{f04d}",
    .strikethrough = "\u{f0cc}",
    .table = "\u{f0ce}",
    .tag = "\u{f02b}",
    .telegram = "\u{f2c6}",
    .thermometer = "\u{f2c7}",
    .trash = "\u{f1f8}",
    .tree = "\u{f1bb}",
    .trophy = "\u{f091}",
    .umbrella = "\u{f0e9}",
    .project = "\u{f502}",
    .video = "\u{f52c}",
    .zig = "\u{e6a9}",
};
