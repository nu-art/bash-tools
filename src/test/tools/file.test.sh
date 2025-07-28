#!/bin/bash

source "${MAIN_SOURCE_FOLDER}/tools/file.sh"

test_file_path_resolves_absolute_path() {
  mkdir -p .tmp-file
  touch .tmp-file/sample.txt
  local result

  result="$(file.path .tmp-file/sample.txt)"

  expect "$result" to.match "/.*/.tmp-file/sample.txt"
  rm -rf .tmp-file
}

test_file_path_resolves_parent_dir() {
  mkdir -p .tmp-root/release
  pushd .tmp-root > /dev/null || exit 1

  local dirty_path="release/.."
  local expected result

  expected="$(cd "$dirty_path" && pwd)"
  result="$(file.path "$dirty_path")"

  popd > /dev/null || exit 1
  rm -rf .tmp-root

  expect "$result" to.equal "$expected"
}

test_file_path_resolves_nested_parent_dirs() {
  mkdir -p .tmp-root/release/child
  pushd .tmp-root/release > /dev/null || exit 1

  local dirty_path="../.."
  local expected result

  expected="$(cd "$dirty_path" && pwd)"
  result="$(file.path "$dirty_path")"

  popd > /dev/null || exit 1
  rm -rf .tmp-root

  expect "$result" to.equal "$expected"
}
