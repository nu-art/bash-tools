#!/bin/bash

import "$MAIN_SOURCE_FOLDER/file-system/folder.sh"
import "$MAIN_SOURCE_FOLDER/bash-it/expect.sh"
import "$MAIN_SOURCE_FOLDER/core/logger.sh"

BUNDLER="${MAIN_SOURCE_FOLDER}/bundler/cli.sh"
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_fixtures"

BUNDLER_DIST_DIR="$TEST_DIST_FOLDER/bundler"
before() {
  folder.delete "$BUNDLER_DIST_DIR"
  folder.create "$BUNDLER_DIST_DIR"
}

after() {
  folder.delete "$BUNDLER_DIST_DIR"
}

## @test: successful bundling
## @expect: exit-code == 0, file generated and contains main logic
test_successful_bundle() {
  local source="$TEST_DIR/ok"
  local bundled="$BUNDLER_DIST_DIR/bundle.ok.sh"

  expect.run "bash \"$BUNDLER\" --source \"$source\" --dist \"$BUNDLER_DIST_DIR\"" to.exit.with 0
  expect "$(cat "$bundled")" to.contain "Hello from OK"
}

## @test: missing sourced file triggers error
## @expect: exit-code != 0
test_missing_source_file() {
  expect.run "bash \"$BUNDLER\" --source \"$TEST_DIR/missing\" --dist \"$BUNDLER_DIST_DIR\"" to.fail.with 1 "Missing sourced file"
}

## @test: avoids duplicate inclusion
## @expect: file contains only once
test_duplicate_inclusion_avoided() {
  local source="$TEST_DIR/duplicate"
  local bundled="$BUNDLER_DIST_DIR/bundle.duplicate.sh"

  bash "$BUNDLER" --source "$source" --dist "$BUNDLER_DIST_DIR"
  local match_count
  match_count=$(grep -c "function_from_common()" "$bundled")
  expect "$match_count" to.equal 1
}

## @test: output cleaned from shebang and source
## @expect: no shebang, no source
test_output_cleaned() {
  local source="$TEST_DIR/ok"
  local bundled="$BUNDLER_DIST_DIR/bundle.ok.sh"

  bash "$BUNDLER" --source "$source" --dist "$BUNDLER_DIST_DIR"
  expect "$(cat "$bundled")" to.not.contain "source "
  expect "$(cat "$bundled")" to.not.contain "import "
}

## @test: nested import handled
## @expect: all dependencies inlined
test_recursive_imports() {
  local source="$TEST_DIR/nested"
  local bundled="$BUNDLER_DIST_DIR/bundle.nested.sh"

  bash "$BUNDLER" --source "$source" --dist "$BUNDLER_DIST_DIR"
  expect "$(cat "$bundled")" to.contain "nested_func()"
  expect "$(cat "$bundled")" to.contain "base_func()"
}

## @test: no leftover __DIR vars in output
## @expect: path resolution variables are stripped
test_removes_dir_resolution_vars() {
  local source="$TEST_DIR/nested"
  local bundled="$BUNDLER_DIST_DIR/bundle.nested.sh"

  bash "$BUNDLER" --source "$source" --dist "$BUNDLER_DIST_DIR"
  expect "$(cat "$bundled")" to.not.contain 'BASH_SOURCE[0]'
  expect "$(cat "$bundled")" to.not.contain 'dirname'
  expect "$(cat "$bundled")" to.not.contain 'cd "$(dirname'
}

## @test: handles custom import syntax
## @expect: file is bundled with imported logic and produces output
test_import_statement_supported() {
  local source="$TEST_DIR/import-test"
  local bundled="$BUNDLER_DIST_DIR/bundle.import-test.sh"

  bash "$BUNDLER" --source "$source" --dist "$BUNDLER_DIST_DIR"
  expect "$(cat "$bundled")" to.contain "say_hi()"
  expect "$(cat "$bundled")" to.contain "Hi from imported file"
  expect "$(cat "$bundled")" to.not.contain "import "

  local output
  output="$(bash "$bundled")"
  expect "$output" to.equal "Hi from imported file"
}
