#!/bin/bash

## Test Suite: symlink.test.sh
## Description: Validates symlink operations: create, remove, ensure, and query

SYMLINK_TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SYMLINK_TEST_DIR}/../../main/core/importer.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../main/core/importer.sh"

import "../../main/file-system/symlink.sh"

before_each() {
  TMP_SYMLINK_TEST_DIR="${SYMLINK_TEST_DIR}/.tmp-symlink"
  mkdir -p "$TMP_SYMLINK_TEST_DIR"
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  rm -f "$TMP_SYMLINK_TEST_DIR/link"
}

after_each() {
  rm -f "$TMP_SYMLINK_TEST_DIR/link"
  rm -rf "$TMP_SYMLINK_TEST_DIR"
}

test_symlink_create_success() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  symlink.create "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"
  expect.run "[[ -L \"$TMP_SYMLINK_TEST_DIR/link\" ]]" to.return 0
  expect "$(readlink "$TMP_SYMLINK_TEST_DIR/link")" to.equal "$TMP_SYMLINK_TEST_DIR/real-file"
}

test_symlink_create_existing_link_does_nothing() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  ln -s "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"
  symlink.create "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"  # should be no-op
  expect.run "[[ -L \"$TMP_SYMLINK_TEST_DIR/link\" ]]" to.return 0
}

test_symlink_get_target() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  ln -s "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"
  expect.run "symlink.get_target \"$TMP_SYMLINK_TEST_DIR/link\"" to.equal "$TMP_SYMLINK_TEST_DIR/real-file"
}

test_symlink_is_link_positive() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  ln -s "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"
  expect.run "symlink.is_link \"$TMP_SYMLINK_TEST_DIR/link\"" to.return 0
}

test_symlink_is_link_negative() {
  touch "$TMP_SYMLINK_TEST_DIR/not-a-link"
  expect.run "symlink.is_link \"$TMP_SYMLINK_TEST_DIR/not-a-link\"" to.return 1
}

test_symlink_remove() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  ln -s "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"
  symlink.remove "$TMP_SYMLINK_TEST_DIR/link"
  expect.run "[[ ! -e \"$TMP_SYMLINK_TEST_DIR/link\" ]]" to.return 0
}

test_symlink_ensure_replaces_wrong_target() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  touch "$TMP_SYMLINK_TEST_DIR/alt-file"
  ln -s "$TMP_SYMLINK_TEST_DIR/alt-file" "$TMP_SYMLINK_TEST_DIR/link"
  symlink.ensure "$TMP_SYMLINK_TEST_DIR/real-file" "$TMP_SYMLINK_TEST_DIR/link"
  expect "$(readlink "$TMP_SYMLINK_TEST_DIR/link")" to.equal "$TMP_SYMLINK_TEST_DIR/real-file"
}

test_symlink_ensure_fails_on_regular_file() {
  touch "$TMP_SYMLINK_TEST_DIR/real-file"
  touch "$TMP_SYMLINK_TEST_DIR/link"
  expect.run "symlink.ensure \"$TMP_SYMLINK_TEST_DIR/real-file\" \"$TMP_SYMLINK_TEST_DIR/link\"" to.return 1
}
