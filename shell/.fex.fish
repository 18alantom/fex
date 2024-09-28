# Sets up a fish widget

function fex-launch-widget -d "Launch fex on ^f"

  # setting global variable for fex
  set -g FEX_COMMAND fex 

  # execute and capture output of $FEX_COMMAND in exec_cmd
  set exec_cmd (eval $FEX_COMMAND)
  
  # inary on fex
  if test -z "$exec_cmd"
    commandline -f repaint
    return
  end 

  eval $exec_cmd 

  # cleaning after execution 
  commandline -f repaint
end

bind \cf fex-launch-widget
# Ref's
# What is eval ? - https://fishshell.com/docs/current/cmds/eval.html
# https://github.com/junegunn/fzf/blob/master/shell/key-bindings.fish 
