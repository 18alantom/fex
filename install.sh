#!/usr/bin/env bash

set -euo pipefail

readonly version=0.1.1
readonly base_dir=$(pwd)
readonly fex_target_dir="$HOME/.fex"
readonly fex_path="$fex_target_dir/bin"
untar_dir=""

readonly red="\x1b[31m"
readonly yellow="\x1b[33m"
readonly green="\x1b[32m"
readonly faint="\x1b[2m"
readonly reset="\x1b[m"
readonly logo="\x1b[46m \x1b[m\x1b[43m  \x1b[m"
readonly check="${green}✔${reset}"

function install() {
  echo -e "Installing fex $logo"
  if [[ $(can_install) == "n" ]]; then
    error "Installation cancelled"
  fi

  local tar_name=$(get_tar_name)
  echo -n "Downloading $tar_name from GitHub "
  local folder_name=$(download $tar_name)
  echo -e "$check"

  untar_dir=$base_dir/$folder_name

  echo -n "Placing binary at $fex_target_dir "
  place_binary
  echo -e "$check"

  if [[ $(ask "Setup fex default command?") == "y" ]]; then
    setup_defaults
  fi
  
  if [[ $(which_shell) == "zsh" && $(ask "Setup zsh configuration?") == "y" ]]; then
    setup_zsh
  fi
  
  cleanup
  echo -e "Installation complete $check"
  echo "Restart your shell to use fex"
}

function get_tar_name() {
  local target_stub=""
  case $(uname -sm) in
    "Darwin arm64")  target_stub="aarch64-macos"   ;;
    "Darwin x86_64") target_stub="x86_64-macos"    ;;
    "Linux x86_64")  target_stub="x86_64-linux"    ;;
    *) error "Binary unavailable for $(uname -sm)" ;;
  esac

  echo "fex-$version-$target_stub.tar.gz"
}

function can_install() {
  if ! command -v "fex" &> /dev/null; then
    echo "y"
    return
  fi

  local bin_path=$(command -v "fex")
  local installed_version=$($bin_path --version)

  ask "Found version $installed_version installed, overwrite with $version?"
}

function download() {
  local tar_name=$1

  if ! command -v "curl" &> /dev/null; then
    error "File cannot be downloaded, curl not found"
  fi
  
  local file_name="fex.tar.gz"
  if [[ -f $file_name ]]; then
    rm $file_name
  fi

  local url="https://github.com/18alantom/fex/releases/download/v$version/$tar_name"
  curl -fsSL $url --output $file_name
  tar --no-same-owner -xzf $file_name
  rm $file_name
  
  local folder_name=${tar_name%.tar.gz}
  if [[ ! -d $folder_name ]]; then
    error "$folder_name not found after downloading"
  fi

  echo $folder_name
}

function place_binary() {
  cd $untar_dir

  if [[ ! -f "fex" ]]; then
    error "Binary (fex) not found at $(pwd)"
  fi

  chmod +x fex
  local output=$(./fex --version 2>&1)

  if [[ $? -ne 0 ]]; then
    error "Invalid binary, error: $output"
  fi
  
  if [[ "$output" != "$version" ]]; then
    error "Invalid version: $output"
  fi
  
  if [[ -f "$fex_path/fex" ]]; then
    rm "$fex_path/fex"
  fi
  
  mkdir -p $fex_path
  mv ./fex "$fex_path/fex"

  update_path
}

function update_path() {
  local path_update_line="[[ ! \$PATH == *$fex_path* ]] && export PATH=\"$fex_path:\$PATH\""
  local rc_path=$(which_rc)
  
  if grep -q "export PATH=\"$fex_path:\$PATH\"" $rc_path; then
    return
  fi
  
  echo "$path_update_line" >> $rc_path
}


function setup_defaults() {
  local default_command="export FEX_DEFAULT_COMMAND=\"fex"

  # Show icons
  if [[ $(ask "Display icons?") == "n" ]]; then
    default_command+=" --no-icons"
  fi
  
  # Show item size
  if [[ $(ask "Display size?") == "n" ]]; then
    default_command+=" --no-size"
  fi

  # Show perm info
  if [[ $(ask "Display permissions?") == "n" ]]; then
    default_command+=" --no-perm"
  fi

  # Show time
  local display_time=$(ask "Display time?")
  if [[ $display_time == "n" ]]; then
    default_command+=" --no-time"
  fi
  
  # Which time to set, defaults to changed.
  if [[ $display_time == "y" ]]; then
    local time_type=$(mcq "Select which time to display" "modified accessed changed")
    default_command+=" --time-type $time_type"
  fi
  default_command+="\""
  set_default_command "$default_command"
}

function set_default_command() {
  local new_command=$1
  local rc_path=$(which_rc)
  if old_command=$(grep "export FEX_DEFAULT_COMMAND=" $rc_path); then
    sed -i".bac" "s/$old_command/$new_command/" $rc_path
    rm $rc_path.bac
  else
    echo $new_command >> $rc_path
  fi
}

function setup_zsh() {
  if [[ ! -f ./.fex.zsh ]]; then
    error "Zsh file (.fex.zsh) not found at $(pwd)"
  fi
  
  local widget_path="$fex_target_dir/.fex.zsh"
  # Remove old fex-widget if present
  if [[ -f $widget_path ]]; then
    rm $widget_path
  fi
  
  mv ./.fex.zsh $widget_path
  
  local rc_path=$(which_rc)
  local load_widget="[ -f $widget_path ] && source $widget_path"
  
  if ! grep -q "$load_widget" $rc_path; then
    echo $load_widget >> $rc_path
  fi
  
  # Key binding already exists
  if grep -q "^bindkey.*fex-widget" $rc_path; then
    return
  fi

  local bind_ctrlf="bindkey '^f' fex-widget"
  if [[ $(ask "Bind CTRL-F to invoke fex?") == "y" ]]; then
    echo $bind_ctrlf >> $rc_path
  else
    echo "Check https://github.com/18alantom/fex?tab=readme-ov-file#zsh-setup for info on custom keybinds"
  fi
}

function which_rc() {
  case $(which_shell) in
    "zsh")  echo "$HOME/.zshrc"  ;;
    "bash") echo "$HOME/.bashrc" ;;
    *)      echo "$HOME/.bashrc" ;;
  esac
}

function which_shell() {
  local shells="zsh bash"
  for s in $shells; do
    if echo "$SHELL" | grep -q "$s"; then
      echo "$s"
      break
    fi
  done
}

function error() {
  echo -e "\n${red}Error${reset}: $1"
  cleanup
  exit 1
}

function ask() {
  read -p "$(echo -e "$yellow>$reset $1 $faint([y]/n)$reset: ")" -r
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "n"
    return
  fi
  
  echo "y"
}

function mcq() {
  local items
  read -r -a items <<< "$2"
  local len=${#items[@]}

  local prompt="$1\n"
  prompt+="$yellow>$reset "
  for (( i=0; i<$len; i++ )); do
    prompt+=${items[$i]}
    if [[ $i -eq 0 ]]; then
      prompt+=" $faint[$i]$reset, "
    elif [[ $i -eq $((len - 1)) ]]; then
      prompt+=" $faint($i)$reset"
    else
      prompt+=" $faint($i)$reset, "
    fi
  done
  prompt+=":"

  read -p "$(echo -e $prompt) " -r
  local idx=$REPLY
  
  if ! [[ $idx =~ ^[0-9]$ ]]; then
    idx=0
  fi

  if [[ $idx -ge $len ]]; then
    idx=0
  fi

  echo "${items[$idx]}"
}

function cleanup() {
  cd $base_dir

  if [[ -d $untar_dir ]]; then 
    rm -rf $untar_dir
  fi
  
  if [[ -f "$base_dir/install.sh" ]]; then
    rm "$base_dir/install.sh"
  fi
}

install || cleanup