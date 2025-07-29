#!/bin/bash

import "${MAIN_SOURCE_FOLDER}/index.sh"

TEMP_TEST_DIR="${TEST_DIST_FOLDER}/.tmp-fs"
before_each() {
  ORIG_DIR="$(pwd)"
  mkdir -p "${TEMP_TEST_DIR}/nested"
}

after_each() {
  cd "$ORIG_DIR" || exit 1
  rm -rf "${TEMP_TEST_DIR}"
}

test_folder_workingDirectory_returns_basename() {
  cd "${TEMP_TEST_DIR}" || exit 1
  expect "$(folder.workingDirectory)" to.equal ".tmp-fs"
}

test_folder_myDir_returns_script_dir() {
  expect "$(folder.myDir)" to.contain "/src/test/file-system"
}

test_folder_exists_positive() {
  expect.run "$(folder.exists "${TEMP_TEST_DIR}")" to.return 0
}

test_folder_isDirectory_true() {
  expect.run "$(folder.isDirectory "${TEMP_TEST_DIR}")" to.return 0
}

test_folder_create_and_delete() {
  local test_folder="${TEMP_TEST_DIR}/new-dir"
  folder.create "${test_folder}"
  expect.run "$(folder.exists "${test_folder}")" to.return 0
  folder.delete "${test_folder}"
  expect.run "$(folder.exists "${test_folder}")" to.return 0
}

test_folder_clear_clears_content() {
  mkdir -p "${TEMP_TEST_DIR}/clear-me/inner"
  touch "${TEMP_TEST_DIR}/clear-me/file.txt"
  folder.clear "${TEMP_TEST_DIR}/clear-me"
  local contents
  contents=$(ls -A "${TEMP_TEST_DIR}/clear-me" | wc -l | xargs)
  expect "$contents" to.equal "0"
}

test_folder_list_outputs_subdirs() {
  local out
  mkdir -p "${TEMP_TEST_DIR}/a" "${TEMP_TEST_DIR}/b"
  out=$(folder.list "${TEMP_TEST_DIR}")
  expect "$out" to.contain "a"
  expect "$out" to.contain "b"
}
