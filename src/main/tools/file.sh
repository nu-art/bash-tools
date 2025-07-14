#!/bin/bash

## @function: file.path(file)
##
## @description: Resolves the absolute path to a given file or directory, handling relative and dirty paths
##
## @return: absolute normalized path
file.path() {
  local input="$1"

  if [[ -d "$input" ]]; then
    cd "$input" > /dev/null || return 1
    pwd -P
  else
    local dir part
    dir="$(cd "$(dirname "$input")" > /dev/null && pwd -P)"
    part="$(basename "$input")"
    echo "$dir/$part"
  fi
}

## @function: file.relative_path(path, parent_dir)
##
## @description: Returns the relative path from parent_dir to the given path
##               If parent_dir is not provided, uses current working directory
##
## @return: relative path starting with ./
file.relative_path() {
  local path parent
  path="$(file.path "$1")"
  parent="$(file.path "${2:-$(pwd)}")"

  echo "./${path#"$parent"/}"
}
