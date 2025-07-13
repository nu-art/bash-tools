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


