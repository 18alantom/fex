# Sets up a fish widget

function fex-launch-widget -d "Launch fex on ^f"
  # setting variable for fex
  set -g FEX_COMMAND fex  

  # execute and capture output of $FEX_COMMAND in exec_cmd
  set exec_cmd (eval $FEX_COMMAND)

  if test -z "$exec_cmd"
    commandline -f repaint
    return
  else 
    # print the command which will be executed
    echo $exec_cmd
    eval $exec_cmd
  end
  
  # cleaning after execution (jump to prompt on newline)
  commandline -f repaint
end

bind \cf fex-launch-widget

# Ref's
# What is eval ? - https://fishshell.com/docs/current/cmds/eval.html
# https://github.com/junegunn/fzf/blob/master/shell/key-bindings.fish 
