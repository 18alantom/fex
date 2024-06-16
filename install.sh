#!/usr/bin/env bash

set -euo pipefail

version=0.0.1
# TODO:
# - Check arch, os
# - Download correct release depending on os, arch
# -
#

function install() {
  tar_name=$(get_tar_name)
  echo "File name will be $tar_name"
}

function error() {
  echo $1
  exit 1
}

function get_tar_name() {
  local target_stub=""
  case $(uname -sm) in
    "Darwin arm64")  target_stub="aarch64-macos"   ;;
    "Darwin x86_64") target_stub="x86_64-linux"    ;;
    "Linux x86_64")  target_stub="x86_64-linux"    ;;
    *) error "Binary unavailable for $(uname -sm)" ;;
  esac

  echo "fex-$version-$target_stub.tar.gz"
}

# function can_install() {

# }
install
