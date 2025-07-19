#!/bin/bash

## @function: import(path)
##
## @description: Load a bash file only once (like require_once in other languages)
##
## @param: path - The path to the file to import
##
## @example: import "./core/logger.sh"
##
## @note: Keeps a global registry of imported paths to avoid redundant loading
##
## @dependencies: none

[[ "${__loaded_source_importer}" == "true" ]] && return
__loaded_source_importer=true

declare -ga __loaded_files=()
__importer_stack_trace_index=1

## @function: import.__stack_trace_index(index)
##
## @description: Sets the frame index to resolve the import path from (used in expect.run)
import.__stack_trace_index(){
  __importer_stack_trace_index=$1
}

import() {
  local path="$1"
  local stack_index="${__importer_stack_trace_index:-1}"
  __importer_stack_trace_index=1  # reset so next call defaults again

  # Resolve the absolute path (support relative to current caller)
  if [[ "${path}" != /* ]]; then
    local caller="${BASH_SOURCE[$stack_index]}"
    local caller_dir="$(cd "$(dirname "$caller")" && pwd)"
    local resolved_path="${caller_dir}/${path}"
    local dir part
    dir="$(cd "$(dirname "$resolved_path")" > /dev/null && pwd -P)"
    part="$(basename "$resolved_path")"
    path="$dir/$part"
  fi

  [[ -d "$path" ]] && {
    echo "import error: '$path' is a directory, not a file" >&2
    return 1
  }

  [[ ! -f "$path" ]] && {
    echo "import error: '$path' does not exist or is not a file" >&2
    return 1
  }

  for loaded in "${__loaded_files[@]}"; do
    [[ "$loaded" == "$path" ]] && return
  done

  # shellcheck disable=SC1090
  source "$path"
  __loaded_files+=("$path")
}
