#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "./expect.sh"
import "../file-system/folder.sh"
import "../core/logger.sh"

REPO_ROOT="$(folder.repo_root)"
MAIN_SOURCE_FOLDER="$REPO_ROOT/src/main"
TEST_SOURCE_FOLDER="$REPO_ROOT/src/test"
MAIN_DIST_FOLDER="$REPO_ROOT/dist"
TEST_DIST_FOLDER="$REPO_ROOT/dist-test"

tests.run(){
  tests.find_files() {
    find . -type f -name "*.test.sh" | sort | grep -E ".*${FILE_NAME_FILTER}.*"
  }

  tests.collect_tests() {
    local all_tests=()
    for test_file in $(tests.find_files); do
      mapfile -t funcs < <(grep -Eo '^test_[a-zA-Z0-9_]+' "$test_file")

      if [[ -n "$TEST_NAME_FILTER" ]]; then
        funcs=($(printf "%s\n" "${funcs[@]}" | grep -E ".*${TEST_NAME_FILTER}.*"))
      fi

      if [[ "${#funcs[@]}" -gt 0 ]]; then
        all_tests+=("${funcs[@]}")
      fi
    done

    echo "${#all_tests[@]}"
  }

  tests.run_tests_in_file() {
    local test_file="$1"

    mapfile -t TEST_FUNCS < <(grep -Eo '^test_[a-zA-Z0-9_]+' "$test_file")

    if [[ -n "$TEST_NAME_FILTER" ]]; then
      TEST_FUNCS=($(printf "%s\n" "${TEST_FUNCS[@]}" | grep -E ".*${TEST_NAME_FILTER}.*"))
    fi

    [[ "${#TEST_FUNCS[@]}" -eq 0 ]] && return

    log.info ""
    log.info "# Running tests from file: $test_file"

    # shellcheck disable=SC1090
    source "$(pwd)/${test_file}"

    if declare -F before > /dev/null; then before; fi

    for test_fn in "${TEST_FUNCS[@]}"; do
      if declare -F before_each > /dev/null; then before_each; fi
      if output=$("$test_fn" 2>&1); then
        log.info "ok   $TEST_COUNTER - $test_fn"
        ((PASS_COUNT=PASS_COUNT+1))
      else
        log.error "not ok $TEST_COUNTER - $test_fn"
        echo "$output" | sed 's/^/#   /'
        ((FAIL_COUNT=FAIL_COUNT+1))
      fi

      ((TEST_COUNTER=TEST_COUNTER+1))
      if declare -F after_each > /dev/null; then after_each; fi
      unset -f "$test_fn"
    done

    if declare -F after > /dev/null; then after; fi

    unset -f before 2>/dev/null
    unset -f after 2>/dev/null
    unset -f before_each 2>/dev/null
    unset -f after_each 2>/dev/null
  }

  FILE_NAME_FILTER="$1"
  TEST_NAME_FILTER="$2"
  OUTPUT_FILE="$3"

  PASS_COUNT=0
  FAIL_COUNT=0

  if [[ -n "$OUTPUT_FILE" ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    exec > "$OUTPUT_FILE"
  fi

  log.info "TAP version 13"

  TOTAL_TESTS=$(tests.collect_tests)
  log.info "1..$TOTAL_TESTS"

  TEST_COUNTER=1
  for test_file in $(tests.find_files); do
    tests.run_tests_in_file "$test_file"
  done

  # --- Summary ---
  log.info "#"
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    log.warning "# Tests:   $TOTAL_TESTS"
    log.info    "# Passed:  $PASS_COUNT"
    log.error   "# Failed:  $FAIL_COUNT"
  else
    log.info    "# Tests:   $TOTAL_TESTS"
    log.info    "# Passed:  $PASS_COUNT"
    log.info    "# Failed:  $FAIL_COUNT"
  fi
  log.info "#"

  return $(( FAIL_COUNT > 0 ? 1 : 0 ))
}
