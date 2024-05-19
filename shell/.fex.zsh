# Sets up ZSH widget for fex, this is needed for
# - launching fex with a shortcut
# - executing commands such as `cd` from fex

# Stores ZSH before initialization options in `__fex_pre_init_options`
# such that evaluating the variable will restore the options.
# 
# The variable is evaluated in the `always` block after setting up
# the fex ZSH widget.
#
# Taken, mostly verbatim, from:
# - https://github.com/junegunn/fzf/blob/master/shell/completion.zsh
if 'zmodload' 'zsh/parameter' 2>'/dev/null' && (( ${+options} )); then
  __fex_pre_init_options="options=(${(j: :)${(kv)options[@]}})"
else
  () {
    __fex_pre_init_options="setopt"
    'local' '__fex_opt'
    for __fex_opt in "${(@)${(@f)$(set -o)}%% *}"; do
      if [[ -o "$__fex_opt" ]]; then
        __fex_pre_init_options+=" -o $__fex_opt"
      else
        __fex_pre_init_options+=" +o $__fex_opt"
      fi
    done
  }
fi

'emulate' 'zsh' '-o' no_aliases

{
  
FEX_COMMAND=${FEX_DEFAULT_COMMAND:-fex}

function __fex_exec {
  setopt localoptions pipefail no_aliases 2> /dev/null

  local item
  # Echo every '\n' delimited item written to stdout
  # the (q) ensures `item` is treated as a single word
  # even if spaces.
  $(echo $FEX_COMMAND) "$@" < /dev/tty | while read item; do
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

    # Single echo to preserve current prompt
    echo
    
    EXEC_CMD="$(__fex_exec)"

    # Return code of executed fex returned command
    local ret=$?
    
    # If no return value (normal quit) then reset prompt
    if [[ -z "$EXEC_CMD" ]]; then
      zle reset-prompt
      return $ret
    fi

    # Pushes BUFFER onto stack and clears it
    zle push-line

    # BUFFER is ZSH env var, accept-line execs what's in BUFFER
    BUFFER=$EXEC_CMD
    zle accept-line
    zle reset-prompt

    return $ret
}

# Register ZSH widget fex-widget
zle -N fex-widget

} always {
  # Restore the original options.
  eval $__fex_pre_init_options
  'unset' '__fex_pre_init_options'
}

# References:
# - https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh
# - https://github.com/junegunn/fzf/blob/master/shell/completion.zsh
# - https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html