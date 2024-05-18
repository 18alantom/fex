// TODO: Probably should be a file
pub const help_string =
    \\Usage
    \\  fex [path] [options]
    \\
    \\Example
    \\  fex ~/Desktop --time accessed
    \\
    \\Display Config
    \\  --no-icons          Skip printing icons
    \\  --no-size           Skip printing item sizes
    \\  --no-time           Skip printing time
    \\  --no-mode           Skip printing permission info
    \\  --time VALUE        Set which time is displayed
    \\                      valid: modified, accessed, changed
    \\                      default: modified
    \\
    \\Search Config
    \\  --regular-search    Uses regular search, instead of fuzzy search
    \\  --match-case        Match search query case, instead of ignoring
    \\
    \\Setup
    \\  --setup-zsh         Setup fex ZSH widget and keybind it to CTRL-F
    \\
    \\Meta
    \\  --help              Print this help message
    \\
    \\Navigation Controls
    \\  j, <down-arrow>     Cursor down
    \\  k, <up-arrow>       Cursor up
    \\  h, <left-arrow>     Up a dir
    \\  l, <right-arrow>    Down a dir
    \\  gg                  Jump to first item
    \\  G                   Jump to last item
    \\  {                   Jump to prev fold
    \\  }                   Jump to next fold
    \\  
    \\Action Controls
    \\  <enter>             Toggle directory or open file (macOS)
    \\  o                   Open item under cursor (macOS)
    \\  E                   Expand all directories
    \\  C                   Collapse all directories
    \\  R                   Change root to item under cursor (if dir)
    \\  I                   Toggle item stat info
    \\  /                   Toggle search mode
    \\  :                   Toggle command mode
    \\  1..9                Expand all directories upto $NUM depth
    \\  q, <ctrl-d>         Quit
    \\
    \\Search Mode Controls
    \\  <escape>            Quit search, restore cursor position
    \\  <enter>             Quit search, toggle directory or open file (macOS)
    \\
    \\Command Mode Controls
    \\  <escape>            Quit command mode
    \\  <enter>             Quit fex, execute command with item under cursor
    \\                      as arg
    \\
    \\File System Commands
    \\  cd                  Quit and change directory to item under cursor (needs setup)
    \\
;
