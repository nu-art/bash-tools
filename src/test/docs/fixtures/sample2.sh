#!/bin/bash

## @function: array.contains
##
## @description: Check if an item is in a list
##
## @param: $1  The item to search for
## @param: $@  The list to search in
##
## @return: true if contained, null otherwise
array.contains() {
  local item="$1"
  shift

  for element in "$@"; do
    if [[ "$element" == "$item" ]]; then
      echo true
      return
    fi
  done

  return
}

## @function: string.join
##
## @description: Join multiple parts with a separator
##
## @param: $1  The separator string
## @param: $@  The strings to join
##
## @return: The joined string
string.join() {
  local sep="$1"
  shift

  local result=""
  for part in "$@"; do
    [[ -n "$result" ]] && result+="$sep"
    result+="$part"
  done

  echo "$result"
}
