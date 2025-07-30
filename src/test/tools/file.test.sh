#!/bin/bash

source "${MAIN_SOURCE_FOLDER}/tools/file.sh"

before_each() {
  TMP_FILE_TEST_DIR="${TEST_DIST_FOLDER}/.tmp-file"
  mkdir -p "$TMP_FILE_TEST_DIR"
}

after_each() {
  rm -rf "$TMP_FILE_TEST_DIR"
}

test_file_path_resolves_absolute_path() {
  touch "$TMP_FILE_TEST_DIR/sample.txt"
  local result
  result="$(file.path "$TMP_FILE_TEST_DIR/sample.txt")"
  expect "$result" to.match "/.*/.tmp-file/sample.txt"
}

test_file_path_resolves_parent_dir() {
  mkdir -p "$TMP_FILE_TEST_DIR/release"
  pushd "$TMP_FILE_TEST_DIR" > /dev/null || exit 1

  local dirty_path="release/.."
  local expected result
  expected="$(cd "$dirty_path" && pwd)"
  result="$(file.path "$dirty_path")"

  popd > /dev/null || exit 1
  expect "$result" to.equal "$expected"
}

test_file_path_resolves_nested_parent_dirs() {
  mkdir -p "$TMP_FILE_TEST_DIR/release/child"
  pushd "$TMP_FILE_TEST_DIR/release" > /dev/null || exit 1

  local dirty_path="../.."
  local expected result
  expected="$(cd "$dirty_path" && pwd)"
  result="$(file.path "$dirty_path")"

  popd > /dev/null || exit 1
  expect "$result" to.equal "$expected"
}

test_file_exists_returns_success() {
  touch "$TMP_FILE_TEST_DIR/test.txt"
  expect.run "file.exists '$TMP_FILE_TEST_DIR/test.txt'" to.return 0
}

test_file_exists_returns_failure() {
  expect.run "file.exists '$TMP_FILE_TEST_DIR/missing.txt'" to.return 1
}

test_file_is_file_returns_success() {
  touch "$TMP_FILE_TEST_DIR/test.txt"
  expect.run "file.is_file '$TMP_FILE_TEST_DIR/test.txt'" to.return 0
}

test_file_is_directory_returns_success() {
  expect.run "file.is_directory '$TMP_FILE_TEST_DIR'" to.return 0
}

test_file_write_and_read() {
  local file="$TMP_FILE_TEST_DIR/write.txt"
  file.write "$file" "hello-world"
  expect "$(file.read "$file")" to.equal "hello-world"
}

test_file_append() {
  local file="$TMP_FILE_TEST_DIR/append.txt"
  file.write "$file" "line1"
  file.append "$file" "line2"
  expect "$(file.read "$file")" to.equal $'line1\nline2'
}

test_file_create_and_delete() {
  local file="$TMP_FILE_TEST_DIR/created.txt"
  file.create "$file"
  expect.run "file.exists '$file'" to.return 0
  file.delete "$file"
  expect.run "file.exists '$file'" to.return 1
}

test_file_find_in_file_returns_match() {
  local file="$TMP_FILE_TEST_DIR/sample.txt"
  echo "version=1.2.3" > "$file"
  expect "$(file.find_in_file "$file" '1\.[0-9]+\.[0-9]+')" to.equal "1.2.3"
}

test_file_find_in_file_returns_empty_when_not_found() {
  local file="$TMP_FILE_TEST_DIR/sample.txt"
  echo "abc" > "$file"
  expect "$(file.find_in_file "$file" 'xyz')" to.be.empty
}

test_file_replace_in_file_replaces_once() {
  local file="$TMP_FILE_TEST_DIR/conf.txt"
  echo "url=http://old.com" > "$file"
  file.replace_in_file "$file" 'http://old.com' 'https://new.com' "" "#"
  expect "$(file.read "$file")" to.equal "url=https://new.com"
}

test_file_name_and_extensions() {
  local path="/tmp/test-file.name.ext"
  expect "$(file.name "$path")" to.equal "test-file.name.ext"
  expect "$(file.extension "$path")" to.equal "ext"
  expect "$(file.no_extension "$path")" to.equal "test-file.name"
}

test_file_relative_path_under_dir() {
  mkdir -p "$TMP_FILE_TEST_DIR/foo"
  touch "$TMP_FILE_TEST_DIR/foo/bar.txt"
  local abs="$(file.path "$TMP_FILE_TEST_DIR/foo/bar.txt")"
  local rel="$(file.relative_path "$abs" "$TMP_FILE_TEST_DIR")"
  expect "$rel" to.equal "./foo/bar.txt"
}

test_file_relative_path_outside_dir_returns_abs() {
  local abs="$(file.path /etc/passwd)"
  local rel="$(file.relative_path "$abs" "$TMP_FILE_TEST_DIR")"
  expect "$rel" to.equal "$abs"
}
