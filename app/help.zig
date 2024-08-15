pub const help_string =
    \\Usage
    \\  fex [path] [options]
    \\
    \\Example
    \\  fex ~/Desktop --time-type accessed
    \\
    \\Display Config
    \\  --[no-]dotfiles     Show or hide dotfiles (default hidden)
    \\  --[no-]icons        Show or hide icons
    \\  --[no-]size         Show or hide item sizes
    \\  --[no-]time         Show or hide time
    \\  --[no-]perm         Show or hide permission info
    \\  --[no-]link         Show or hide link target
    \\  --[no-]user         Show or hide user name
    \\  --[no-]group        Show or hide group name
    \\  --time-type VALUE   Set which time is displayed
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
    \\  --version           Print the version and quit
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
    \\  <enter>             Toggle directory or open file
    \\  o                   Open item under cursor
    \\  E                   Expand all directories
    \\  C                   Collapse all directories
    \\  R                   Change root to item under cursor (if dir)
    \\  /                   Toggle search mode
    \\  :                   Toggle command mode
    \\  1..9                Expand all directories upto $NUM depth
    \\  <tab>               Toggle item selection under cursor
    \\  q, <ctrl-d>         Quit
    \\
    \\Search Mode Controls
    \\  <escape>            Quit search, restore cursor position
    \\  <enter>             Quit search
    \\
    \\Command Mode Controls
    \\  <escape>            Quit command mode
    \\  <enter>             Quit fex, execute command with selected items or item
    \\                      under cursor as arg(s)
    \\
    \\File System Controls
    \\  cd                  Quit and change directory to item under cursor (needs setup)
    \\
    \\Display Toggle Controls
    \\  I                   Toggle item stat info
    \\  .                   Toggle dot files display
    \\  ti                  Toggle icon display
    \\  tp                  Toggle permission info display
    \\  ts                  Toggle size display
    \\  tt                  Toggle time display
    \\  tl                  Toggle link target display
    \\  tu                  Toggle user name display
    \\  tg                  Toggle group name display
    \\  tm                  Display modified time
    \\  ta                  Display accessed time
    \\  tc                  Display changed time
    \\
    \\Sort Controls
    \\  sn                  Sort in ascending order by name
    \\  ss                  Sort in ascending order by size
    \\  st                  Sort in ascending order by displayed time
    \\  sdn                 Sort in descending order by name
    \\  sds                 Sort in descending order by size
    \\  sdt                 Sort in descending order by displayed time
    \\
;
