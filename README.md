![fex logo bar](https://github.com/18alantom/fex/assets/29507195/f8f6ece5-14bb-4361-8d79-c2d5fb145fd4)

**A command-line file explorer.**

---

`fex` is a command-line file explorer inspired by
[Vim](<https://en.wikipedia.org/wiki/Vim_(text_editor)>),
[exa](https://github.com/ogham/exa) and
[fzf](https://github.com/junegunn/fzf?tab=readme-ov-file#installation), built with
quick exploration and navigation in mind.

<img width="949" alt="fex screenshot" src="https://github.com/18alantom/fex/assets/29507195/61a4b2a2-19a2-44ca-9c71-27f70415d7ca">

By using Vim-like keybindings, `fex` ends up being a near-effortless
tool to zip around a file system:

- `j`, `k` to move to the pervious and next item
- `h`, `l` to move up or drop down a directory
- `/` to search for items
- `:` to run commands on the selected item

<details>
<summary><strong>Show Fex Demo</strong></summary>
 
[Fex Demo.webm](https://github.com/18alantom/fex/assets/29507195/04bb6078-c8f0-4e27-88db-79b81c1e6429)

</details>

## Index

- [Installation](#installation)
  - [Using `install.sh`](#using-installsh)
  - [From Source](#from-source)
    - [macOS](#macos)
    - [Linux](#linux)
- [Setup](#setup)
  - [Zsh Setup](#zsh-setup)
  - [fex Default Command](#fex-default-command)
- [Config](#config)
  - [Display Config](#display-config)
  - [Search Config](#search-config)
  - [Other Args](#other-args)
- [Controls](#controls)
  - [Navigation Controls](#navigation-controls)
  - [Action Controls](#action-controls)
  - [File System Controls](#file-system-controls)
  - [Search Mode Controls](#search-mode-controls)
  - [Command Mode Controls](#command-mode-controls)
  - [Display Toggle Controls](#display-toggle-controls)
  - [Sort Controls](#sort-controls)
- [Platorm Support](#platform-support)

## Installation

The most convenient way is by running the following bash one-liner:

```bash
curl -O https://raw.githubusercontent.com/18alantom/fex/master/install.sh && bash install.sh
```

If you are a Nix user, just run one of the following commands:

```bash
# Run the program immediately:
nix run github:18alantom/fex

# Enter a temporary shell with `fex` available:
nix shell github:18alantom/fex
```

Getting `fex` running involves:

1. Installing the `fex` executable.
2. Setting up the shell integration.

To get install the `fex` executable follow this section. For the shell
integration go to the [Setup](#setup) section.

> [!NOTE]
>
> 🚧 Installation using package managers (Homebrew, apt, etc) will be added.

### Using `install.sh`

You can use [`install.sh`](https://github.com/18alantom/fex/blob/master/install.sh) script to [download](https://github.com/18alantom/fex/releases) and setup fex.

Run the following bash one-liner to setup fex:

```bash
curl -O https://raw.githubusercontent.com/18alantom/fex/master/install.sh && bash install.sh
```

> [!NOTE]
>
> To uninstall fex:
>
> 1. Remove the `$HOME/.fex` directory.
> 2. Delete the lines pertaining to fex from your `.bashrc` or `.zshrc` file.

### From Source

To install fex from source, you will need version `zig` version 0.13.0 installed. You can get it from [here](https://ziglang.org/download/).

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
# To be able to open files, you will need xdg-open from xdg-utils
sudo apt install xdg-utils
```

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

### Zsh Setup

To setup the Zsh widget for fex, first copy the file `shell/.fex.zsh` to your
home directory. Then copy the following lines into your `.zshrc`:

```bash
# Source .fex.zsh if it's present
[ -f ~/.fex.zsh ] && source ~/.fex.zsh

# Bind CTRL-F to invoke fex (key binds can be custom)
bindkey '^f' fex-widget
```

> [!TIP]
>
> You can change which key is used to invoke `fex` by using the Zsh `bindkey` command.
> For example if you use Zsh vi mode, you can use `bindkey -a 'f' fex-widget` to
> invoke `fex` using the `'f'` key when in command mode.
>
> Reference:
>
> - ZLE manpage (`man zshzle`), the ZLE BUILTINS section.
> - [Binding Keys and handling keymaps](https://zsh.sourceforge.io/Guide/zshguide04.html#l93)

### `fex` Default Command

After you have set up fex for your shell, you can `FEX_DEFAULT_COMMAND` to change
what flags `fex` is invoked using. For example:

```bash
# Sets time displayed to access time and hides icons
export FEX_DEFAULT_COMMAND="fex --time-type accessed --no-icons"
```

## Config

You can configure `fex` by passing it args.

> [!NOTE]
>
> Config is picked up from the `FEX_DEFAULT_COMMAND` envvar and CLI args
> passed when calling `fex`. CLI args take precedence.

### Display Config

Changes values displayed in an item line.

| arg                 | description                                                                                             |
| :------------------ | :------------------------------------------------------------------------------------------------------ |
| `--[no-]icons`      | Show or hide icons. Note: icons need a [patched font](https://github.com/ryanoasis/nerd-fonts) to work. |
| `--[no-]size`       | Show or hide item sizes                                                                                 |
| `--[no-]time`       | Show or hide time                                                                                       |
| `--[no-]perm`       | Show or hide permission info                                                                            |
| `--[no-]link`       | Show or hide link target                                                                                |
| `--[no-]user`       | Show or hide user name                                                                                  |
| `--[no-]group`      | Show or hide group name                                                                                 |
| `--time-type VALUE` | Set which time is displayed. VALUE: modified, accessed, changed. Default: modified                      |

### Search Config

This changes search behavior.

| arg              | description                                  |
| :--------------- | :------------------------------------------- |
| --regular-search | Uses regular search, instead of fuzzy search |
| --match-case     | Match search query case, instead of ignoring |

> [!TIP]
>
> `fex` uses smart case matching by default i.e case is ignored until you
> enter an upper case character.

### Other Args

| arg         | description                        |
| :---------- | :--------------------------------- |
| `--help`    | Prints the help message and quits. |
| `--version` | Prints the version and quits.      |

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
| `<enter>`       | Toggle directory or open file             |
| `o`             | Open item                                 |
| `E`             | Expand all directories under root         |
| `C`             | Collapse all directories                  |
| `R`             | Change root to item under cursor (if dir) |
| `I`             | Toggle item stat info                     |
| `1..9`          | Expand all directories up to $NUM depth   |
| `q`, `<ctrl-d>` | Quit                                      |
| `<tab>`         | Toggle item selection under cursor        |
| `/`             | Toggle search mode                        |
| `:`             | Toggle command mode                       |

### File System Controls

| key  | action                                                                 |
| :--- | :--------------------------------------------------------------------- |
| `cd` | Quit and change directory to item under cursor (needs [setup](#setup)) |

### Search Mode Controls

Type `/` in regular mode to initiate search mode.

| key        | action                                             |
| :--------- | :------------------------------------------------- |
| `<escape>` | Quit search, restore cursor to pre-search position |
| `<enter>`  | Quit search, cursor stays on found item            |

### Command Mode Controls

Type `:` in regular mode to initiate command mode.

| key        | action                                                                       |
| :--------- | :--------------------------------------------------------------------------- |
| `<escape>` | Quit command mode                                                            |
| `<enter>`  | Quit fex, execute command with selected items or item under cursor as arg(s) |

### Display Toggle Controls

Toggle displayed information.

| key  | action                         |
| :--- | :----------------------------- |
| `I`  | Toggle item stat info          |
| `ti` | Toggle icon display            |
| `tp` | Toggle permission info display |
| `ts` | Toggle size display            |
| `tt` | Toggle time display            |
| `tl` | Toggle link target display     |
| `tu` | Toggle user name display       |
| `tg` | Toggle group name display      |
| `tm` | Display modified time          |
| `ta` | Display accessed time          |
| `tc` | Display changed time           |

### Sort Controls

Sort entries in a directory.

| key   | action                                     |
| :---- | :----------------------------------------- |
| `sn`  | Sort in ascending order by name            |
| `ss`  | Sort in ascending order by size            |
| `st`  | Sort in ascending order by displayed time  |
| `sdn` | Sort in descending order by name           |
| `sds` | Sort in descending order by size           |
| `sdt` | Sort in descending order by displayed time |

## Platform Support

`fex` should ideally compile and run on all macOS and Linux targets supported
by Zig. Some features such as opening fs items work only on macOS for now.

Portions of `fex` code is platform specific and Windows compatibility has not
been accounted for. This may be added in later.

| arch | macOS   | Linux            | Windows          |
| ---- | ------- | ---------------- | ---------------- |
| arm  | works   | does not compile | does not compile |
| x86  | works\* | works            | does not compile |

Currently fex only has shell integration for Zsh. Fish and Bash integrations will
be added.

_works\*: uses stat instead of lstat for macOS x86 so links may not be shown._
