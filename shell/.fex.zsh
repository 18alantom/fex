'emulate' 'zsh' '-o' no_aliases

function __fex_cmd {
  # Use default command, else fallback to just 'fex'
  echo ${FEX_DEFAULT_COMMAND:-fex}
}

function __fex_exec {
  setopt localoptions pipefail no_aliases 2> /dev/null

  local item
  # Echo every '\n' delimited item written to stdout
  # the (q) ensures `item` is treated as a single word
  # even if spaces.
  $(__fex_cmd) "$@" < /dev/tty | while read item; do
    echo -n "${(q)item} "
  done

  # Set previous command return code to ret so it can
  # be returned.
  local ret=$?
  echo
  return $ret
}

function fex-widget {
    setopt localoptions pipefail no_aliases 2> /dev/null
    EXEC_CMD="$(__fex_exec)"
    
    # If no return value (normal quit) then reset prompt
    # and exit with 0
    if [[ -z "$EXEC_CMD" ]]; then
      zle reset-prompt
      return 0
    fi

    # Pushes BUFFER onto stack and clears it
    zle push-line

    # BUFFER is ZSH env var, accept-line execs what's in BUFFER
    BUFFER=$EXEC_CMD
    zle accept-line

    # Return code of executed fex returned command
    local ret=$?
    
    zle reset-prompt
    return $ret
}

# Register ZSH widget fex-widget
zle -N fex-widget

# Bind CTRL-F to run fex-widget
bindkey '^f' fex-widget


# References:
# - https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html
# - https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh