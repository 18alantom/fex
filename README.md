# fex

A command line file explorer inspired by
[Vim](<https://en.wikipedia.org/wiki/Vim_(text_editor)>),
[exa](https://github.com/ogham/exa) and
[fzf](https://github.com/junegunn/fzf?tab=readme-ov-file#installation).

`fex` is built with quick exploration and navigation in mind. By using Vim-like
keybindings, `fex` ends up being a near-effortless tool to zip around a file
system.

## Installation

Getting `fex` running involves:

1. Installing the `fex` executable.
2. Setting up the shell integration.

To get install the `fex` executable follow this section. For the shell
integration go to the [Setup](#setup) section.

> [!NOTE]
>
> 🚧 installation using package managers (Homebrew, apt, etc) will be added.

### From Source

To install fex from source, you will need version `zig` version 0.12.0 installed. You can get it from [here](https://ziglang.org/download/).

Once you had done that, compile the executable by using the following commands:

```bash
# Clone the fex repository
git clone https://github.com/18alantom/fex && cd fex
```

#### macOS

```bash
# Compile the fex executable for your system
zig build-exe -O ReleaseSafe main.zig

# Move the executable to usr bin
mv main /usr/local/bin/fex
```

#### Linux

```bash
# Compile the fex executable for your system
zig build-exe -O ReleaseSafe main.zig -lc

# Move the executable to usr bin
mv main /usr/bin/fex
```

## Setup

To use `fex` to its full extent it needs to be set up as a shell widget. This
allows fex to:

- Be invoked using a key binding.
- Execute shell commands. For example `cd` to quit and change directory.

These are shell specific so you will need to set it up separately depending on
the shell you use.

> [!NOTE]
>
> 🚧 bash and fish shell support will be added.

### zsh setup

To setup the ZSH widget for fex, first copy the file `shell/.fex.zsh` to your
home directory. Then copy the following lines into your `.zshrc`:

```bash
# Source .fex.zsh if it's present
[ -f ~/.fex.zsh ] && source ~/.fex.zsh

# Bind CTRL-F to invoke fex (key binds can be custom)
bindkey '^f' fex-widget
```

> [!NOTE]
>
> You can change which key is used to invoke `fex` by using the ZSH `bindkey` command.
> Reference: [Binding Keys and handling keymaps](https://zsh.sourceforge.io/Guide/zshguide04.html#l93)

### `fex` Default Command

After you have set up fex for your shell, you can `FEX_DEFAULT_COMMAND` to change
what flags `fex` is invoked using. For example:

```bash
# Sets time displayed to access time and hides icons
export FEX_DEFAULT_COMMAND="fex --time accessed --no-icons"
```

## Config

You can configure `fex` by passing it args.

> [!NOTE]
>
> Config is picked up from the `FEX_DEFAULT_COMMAND` envvar and CLI args
> passed when calling `fex`. CLI args take precedence.

### Display Config

Changes values displayed in an item line.

| arg            | description                                                                                              |
| :------------- | :------------------------------------------------------------------------------------------------------- |
| `--no-icons`   | Skip printing icons. Note: icons need a [patched font](https://github.com/ryanoasis/nerd-fonts) to work. |
| `--no-size`    | Skip printing item sizes                                                                                 |
| `--no-time`    | Skip printing time                                                                                       |
| `--no-mode`    | Skip printing permission info                                                                            |
| `--time VALUE` | Set which time is displayed. VALUE: modified, accessed, changed. Default: modified                       |

### Search Config

This changes search behavior.

| arg              | description                                  |
| :--------------- | :------------------------------------------- |
| --regular-search | Uses regular search, instead of fuzzy search |
| --match-case     | Match search query case, instead of ignoring |

> [!TIP]
>
> `fex` uses a smart case matching where case is ignored only for lowercase
> characters. If you use an uppercase character, `fex` will match case.

### Other Args

| arg              | description                        |
| :--------------- | :--------------------------------- |
| `--help`         | Prints the help message and quits. |
| `--setup-zsh` 🚧 | Sets up the zsh widget and quits.  |

## Controls

`fex` has three modes:

- **Default**: used to navigate around a file system and enter one of the other modes.
- **Search**: toggled with `/`, used to accept a query and find matching items in expanded directories.
- **Command**: toggled with `:`, used to accept a shell command that is executed on `enter`. `fex` needs to be setup as a shell widget for this to work, see [Setup](#setup).

> [!IMPORTANT]
>
> Keys mentioned in angle-brackets such as `<enter>` show which key has to be
> pressed. Keys mentioned without such as `cd` are sequences that have to be
> typed.

### Navigation Controls

| key                  | action                                   |
| :------------------- | :--------------------------------------- |
| `j`, `<down-arrow>`  | Cursor down                              |
| `k`, `<up-arrow>`    | Cursor up                                |
| `h`, `<left-arrow>`  | Up a dir                                 |
| `l`, `<right-arrow>` | Down a dir (if item is a dir)            |
| `gg`                 | Jump to first item in the list           |
| `G`                  | Jump to last item in the list            |
| `{`                  | Jump to prev item with a different level |
| `}`                  | Jump to next item with a different level |

### Action Controls

| key             | action                                    |
| :-------------- | :---------------------------------------- |
| `<enter>`       | Toggle directory or open file (macOS)     |
| `o`             | Open file (macOS)                         |
| `E`             | Expand all directories under root         |
| `C`             | Collapse all directories                  |
| `R`             | Change root to item under cursor (if dir) |
| `I`             | Toggle item stat info                     |
| `1..9`          | Expand all directories upto $NUM depth    |
| `q`, `<ctrl-d>` | Quit                                      |
| `/`             | Toggle search mode                        |
| `:`             | Toggle command mode                       |

### File System Conrols

| key  | action                                                                 |
| :--- | :--------------------------------------------------------------------- |
| `cd` | Quit and change directory to item under cursor (needs [setup](#setup)) |

### Search Mode Controls

Type `/` in regular mode to initiate search mode.

| key        | action                                             |
| :--------- | :------------------------------------------------- |
| `<escape>` | Quit search, restore cursor to pre-search position |
| `<enter>`  | Quit search, toggle directory or open file (macOS) |

### Command Mode Controls

Type `:` in regular mode to initiate command mode.

| key        | action                                                  |
| :--------- | :------------------------------------------------------ |
| `<escape>` | Quit command mode                                       |
| `<enter>`  | Quit fex, execute command with item under cursor as arg |

## Support, Known Issues, and TODO
