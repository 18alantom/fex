#!/usr/bin/env bash

# Release script is used to update the version in
# all the files it's mentioned it, after that to push
# the changes.
# 
# Once that changes have been pushed, a new tag is
# created and pushed. This should trigger the 
# release.yml GitHub Action.
# 
# Once it's complete a new Draft release will be created
# with build artefacts.
# 
# Once the release body has been filled out, hit publish.
set -euo pipefail

readonly red="\x1b[31m"
readonly yellow="\x1b[33m"
readonly green="\x1b[32m"
readonly faint="\x1b[2m"
readonly reset="\x1b[m"
readonly check="${green}✔${reset}"

version=""

function release() {
  version="$1"
  is_valid
  echo -e "Updating version to: $yellow$version$reset"
  
  update_versions
  echo -e "Update versions $check"

  commit_and_push_version_bump
  echo -e "Commit and push version bump $check"
  
  create_and_push_tags
  echo -e "Create and push tags $check"

  echo -e "New workflow will be triggered at:\nhttps://github.com/18alantom/fex/actions/workflows/release.yml"
}

function update_versions() {
  update_file_name
  update_build_zon
  update_args_version
}

function commit_and_push_version_bump() {
  if [[ $(ask "Commit version bump?") == "y" ]]; then
    git add .
    git commit -S -m "bump version to $version"
  else
    error "Aborted at version bump"
  fi

  if [[ $(ask "Push version bump?") == "y" ]]; then
    git push
  else
    error "Aborted at git push"
  fi
}

function create_and_push_tags() {
  if [[ $(ask "Create tag v$version?") == "y" ]]; then
    git tag v$version
  else
    error "Aborted at git tag"
  fi
  
  if [[ $(ask "Push tags?") == "y" ]]; then
    git push --tags
  else
    error "Aborted at git push tags"
  fi
}

function update_file_name() {
  local file_name="install.sh"
  if local old=$(grep "readonly version=" $file_name); then
    local new="readonly version=$version"
    sed -i".bak" "s/$old/$new/" $file_name
    rm $file_name.bak
  fi
}

function update_build_zon() {
  local file_name="build.zig.zon"
  if local old=$(grep "\.version = " $file_name); then
    local new="    \.version = \"$version\","
    sed -i".bak" "s/$old/$new/" $file_name
    rm $file_name.bak
  fi
}

function update_args_version() {
  local file_name="app/args.zig"
  if local old=$(grep "const version =" $file_name); then
    local new="const version = \"$version\";"
    sed -i".bak" "s/$old/$new/" $file_name
    rm $file_name.bak
  fi
}

function is_valid() {
  local version_regex="^[0-9]+\.[0-9]+\.[0-9]+$"
  if ! [[ $version =~ $version_regex ]]; then
    error "Invalid version $version"
  fi
}

function error() {
  echo -e "\n${red}Error${reset}: $1"
  exit 1
}

function ask() {
  read -p "$(echo -e "$yellow>$reset $1 $faint([n]/y)$reset: ")" -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "y"
    return
  fi
  
  echo "n"
}

release $1