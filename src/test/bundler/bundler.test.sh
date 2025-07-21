#!/bin/bash

BUNDLER_TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${BUNDLER_TEST_DIR}/../../main/core/importer.sh"
source "${BUNDLER_TEST_DIR}/../../main/file-system/folder.sh"

source "$BUNDLER_TEST_DIR/../../main/bash-it/expect.sh"
source "$BUNDLER_TEST_DIR/../../main/core/logger.sh"

BUNDLER="$BUNDLER_TEST_DIR/../../main/bundler/bundle.sh"
TEST_DIR="$BUNDLER_TEST_DIR/../bundler/_fixtures"
DIST_DIR="$BUNDLER_TEST_DIR/.expected"

before() {
  folder.delete "$DIST_DIR"
  folder.create "$DIST_DIR"
}

#after() {
#  folder.delete "$DIST_DIR"
#}

## @test: successful bundling
## @expect: exit-code == 0, file generated and contains main logic
test_successful_bundle() {
  local source="$TEST_DIR/ok"
  local bundled="$DIST_DIR/bundle.ok.sh"

  expect.run "bash \"$BUNDLER\" --source \"$source\" --dist \"$DIST_DIR\"" to.exit.with 0
  expect "$(cat "$bundled")" to.contain "Hello from OK"
}

## @test: missing sourced file triggers error
## @expect: exit-code != 0
test_missing_source_file() {
  expect.run "bash \"$BUNDLER\" --source \"$TEST_DIR/missing\" --dist \"$DIST_DIR\"" to.fail.with 1 "Missing sourced file"
}

## @test: avoids duplicate inclusion
## @expect: file contains only once
test_duplicate_inclusion_avoided() {
  local source="$TEST_DIR/duplicate"
  local bundled="$DIST_DIR/bundle.duplicate.sh"

  bash "$BUNDLER" --source "$source" --dist "$DIST_DIR"
  local match_count
  match_count=$(grep -c "function_from_common()" "$bundled")
  expect "$match_count" to.equal 1
}

## @test: output cleaned from shebang and source
## @expect: no shebang, no source
test_output_cleaned() {
  local source="$TEST_DIR/ok"
  local bundled="$DIST_DIR/bundle.ok.sh"

  bash "$BUNDLER" --source "$source" --dist "$DIST_DIR"
  expect "$(cat "$bundled")" to.not.contain "source "
}

## @test: nested import handled
## @expect: all dependencies inlined
test_recursive_imports() {
  local source="$TEST_DIR/nested"
  local bundled="$DIST_DIR/bundle.nested.sh"

  bash "$BUNDLER" --source "$source" --dist "$DIST_DIR"
  expect "$(cat "$bundled")" to.contain "nested_func()"
  expect "$(cat "$bundled")" to.contain "base_func()"
}
