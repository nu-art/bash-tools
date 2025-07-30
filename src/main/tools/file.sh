#!/bin/bash

## @function: file.path(file)
##
## @description: Resolves the absolute path to a given file or directory, handling relative and dirty paths
##
## @return: absolute normalized path
file.path() {
  local input="$1"

  if [[ -d "$input" ]]; then
    cd "$input" > /dev/null || exit 1
    pwd -P

  else
    local dir part
    dir="$(cd "$(dirname "$input")" > /dev/null && pwd -P)"
    part="$(basename "$input")"
    echo "$dir/$part"
  fi
}

## @function: file.relative_path(file, parent_dir)
##
## @description: Returns the relative path from parent_dir to the given file
##               If parent_dir is not provided, uses current working directory
##
## @return: relative path starting with ./
file.relative_path() {
  local path parent
  path="$(file.path "$1")"
  parent="$(file.path "${2:-$(pwd)}")"

  if [[ "$path" == "$parent"* ]]; then
    echo "./${path#"$parent"/}"
  else
    echo "$path"
  fi
}

## @function: file.exists(file)
##
## @description: Checks if the file or directory exists
##
## @return: 0 if exists, 1 otherwise
file.exists() {
  [[ -e "$1" ]]
}

## @function: file.is_file(file)
##
## @description: Checks if the given path is a regular file
##
## @return: 0 if file, 1 otherwise
file.is_file() {
  [[ -f "$1" ]]
}

## @function: file.is_directory(file)
##
## @description: Checks if the given path is a directory
##
## @return: 0 if directory, 1 otherwise
file.is_directory() {
  [[ -d "$1" ]]
}

## @function: file.read(file)
##
## @description: Outputs the contents of the given file
##
## @return: file contents, or exits with error if not found
file.read() {
  local file="$1"
  [[ -f "$file" ]] || error.throw "File not found: $file" 1
  cat "$file"
}

## @function: file.write(file, content)
##
## @description: Writes the content to the file, overwriting it
##
## @return: null
file.write() {
  local file="$1"
  local content="$2"
  echo "$content" > "$file"
}

## @function: file.append(file, content)
##
## @description: Appends the content to the file
##
## @return: null
file.append() {
  local file="$1"
  local content="$2"
  echo "$content" >> "$file"
}

## @function: file.create(file)
##
## @description: Creates an empty file or touches it if it already exists
##
## @return: null
file.create() {
  touch "$1"
}

## @function: file.delete(file)
##
## @description: Deletes the given file if it exists
##
## @return: null
file.delete() {
  [[ -e "$1" ]] && rm -f "$1"
}

## @function: file.find_in_file(file, regex)
##
## @description: Finds the first match of the regex in the file
##
## @return: matched string or null if not found
file.find_in_file() {
  local file="$1"
  local regex="$2"
  grep -oE "$regex" "$file" | head -n1
}

## @function: file.replace_in_file(file, match, replace, flags?, delimiter?)
##
## @description: Replaces substring in file using sed. Optional flags (e.g. 'g') and delimiter (default: /)
##
## @return: null
file.replace_in_file() {
  local file="$1"
  local match="$2"
  local replace="$3"
  local flags="$4"
  local delimiter="${5:-/}"

  local expr="s${delimiter}${match}${delimiter}${replace}${delimiter}${flags}"
  if [[ $(isMacOS) ]]; then
    sed -i '' -E "$expr" "$file"
  else
    sed -i -E "$expr" "$file"
  fi
}

## @function: file.replace_all_in_file(file, match, replace, delimiter?)
##
## @description: Replace all matches in file
##
## @return: null
file.replace_all_in_file() {
  file.replace_in_file "$1" "$2" "$3" g "$4"
}

## @function: file.delete_line_in_file(file, match)
##
## @description: Deletes lines matching the pattern
##
## @return: null
file.delete_line_in_file() {
  local file="$1"
  local match="$2"

  if [[ $(isMacOS) ]]; then
    sed -i '' -E "/${match}/d" "$file"
  else
    sed -i -E "/${match}/d" "$file"
  fi
}

## @function: file.name(file)
##
## @description: Returns the basename of the file
##
## @return: just the filename without path
file.name() {
  basename "$1"
}

## @function: file.extension(file)
##
## @description: Extracts the file extension from a filename
##
## @return: extension part (e.g. 'txt' from 'file.txt')
file.extension() {
  local name
  name="$(basename "$1")"
  echo "${name##*.}"
}

## @function: file.no_extension(file)
##
## @description: Removes the extension from a file name
##
## @return: name without extension
file.no_extension() {
  local name
  name="$(basename "$1")"
  echo "${name%.*}"
}


