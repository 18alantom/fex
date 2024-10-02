# Sets up a fish widget to invoke fex on shortcut

function fex-widget -d "Invokes fex and executes commands from it"
  # setting variable for fex
  set -g FEX_COMMAND fex  

  # execute and capture output of $FEX_COMMAND in exec_cmd
  set exec_cmd (eval $FEX_COMMAND)

  if test -z "$exec_cmd"
    commandline -f repaint
    return
  else
    commandline -f repaint
    # if the $exec_Cmd printed, it prints both the parts (command) and (argument/flag) on new line. So. So, it needs to be joint. `
    set joint_cmd (string join " " $exec_cmd)
    commandline $joint_cmd
    commandline -f execute
  end

  # cleaning after execution
  commandline -f repaint
end


# Ref's
# What is eval ? - https://fishshell.com/docs/current/cmds/eval.html
# https://github.com/junegunn/fzf/blob/master/shell/key-bindings.fish 
