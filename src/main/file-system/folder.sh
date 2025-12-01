#!/bin/bash


source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "../core/logger.sh"
import "../tools/error.sh"



## @function: folder.workingDirectory()
##
## @description: Returns the name of the current directory
##
## @return: string - basename of $PWD
folder.workingDirectory() {
  echo "${PWD##*/}"
}

## @function: folder.myDir(depth)
##
## @description: Gets the directory path of the calling script
##
## @return: string - absolute path
folder.myDir() {
  cd "$(dirname "${BASH_SOURCE[${1:-1}]}")" && pwd
}

## @function: folder.exists(path)
##
## @description: Checks whether the path exists
##
## @return: true if exists
folder.exists() {
  [[ -e "$1" ]]
}

## @function: folder.isDirectory(path)
##
## @description: Checks whether the path is a directory
##
## @return: true if it's a directory
folder.isDirectory() {
  [[ -d "$1" ]]
}

## @function: folder.create(path)
##
## @description: Creates a folder if it doesn't exist
folder.create() {
  local dir="$1"
  [[ -e "$dir" && ! -d "$dir" ]] && error.throw "Path exists but is not a directory: $dir" 1
  mkdir -p "$dir"
}

## @function: folder.clear(path)
##
## @description: Deletes all contents of a folder, without deleting the folder itself
folder.clear() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    rm -rf "${dir:?}"/* "${dir:?}"/.* 2>/dev/null
  else
    error.throw "Not a directory: $dir" 1
  fi
  local dir="$1"
}

## @function: folder.delete(path)
##
## @description: Deletes the given folder and its contents
folder.delete() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    rm -rf "$dir"
  fi
}

## @function: folder.list(subdir)
##
## @description: Lists immediate subdirectories of given path (default: current dir)
folder.list() {
  local path="${1:-.}"
  find "$path" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
}


# Discover the repo root by looking for .git
folder.repo_root() {
  local dir="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
  while [[ "$dir" != "/" ]]; do
    [[ -e "$dir/.git" ]] && file.path "$dir" && return
    dir="$(dirname "$dir")"
  done

  error.throw "Unable to discover REPO_ROOT (missing .git)" 1
}
