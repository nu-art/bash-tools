#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/../../main/tools/file.sh"

test_file_path_resolves_absolute_path() {
  mkdir -p .tmp-file
  touch .tmp-file/sample.txt
  local result

  result="$(file.path .tmp-file/sample.txt)"

  expect "$result" to.match "/.*/.tmp-file/sample.txt"
  rm -rf .tmp-file
}

test_file_path_resolves_parent_dir() {
  local dirty_path="release/.."
  local result

  result="$(file.path "$dirty_path")"

  expect "$result" to.equal "$(cd "$dirty_path" && pwd)"
}

test_file_path_resolves_nested_parent_dirs() {
  local dirty_path="release/../.."
  local expected
  local result

  expected="$(cd "$dirty_path" && pwd)"
  result="$(file.path "$dirty_path")"

  expect "$result" to.equal "$expected"
}
