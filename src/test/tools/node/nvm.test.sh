#!/bin/bash

## Test Suite: nvm.test.sh
## Description: Validates lazy+strict behavior of nvm and node setup logic

import "$MAIN_SOURCE_FOLDER/tools/node/nvm.sh"

NVM_TEST_DIR="$TEST_DIST_FOLDER/tools/nvm"

before_each() {
  mkdir -p "$NVM_TEST_DIR"
  pushd "$NVM_TEST_DIR" > /dev/null || exit 1
  __loaded_files=()
}

after_each() {
  popd > /dev/null || exit 1
  rm -rf "$NVM_TEST_DIR"
  __loaded_files=()
}

test_nvm_source_success() {
  nvm.source
  expect "$?" to.equal "0"
}

test_nvm_install_idempotent() {
  nvm.install
  expect "$?" to.equal "0"
}

test_nvm_setup_runs_end_to_end() {
  echo "18.17.1" > "$NVM_TEST_DIR/.nvmrc"
  nvm.setup
  expect "$?" to.equal "0"
}

test_nvm_uninstall_skipped() {
  echo "SKIP: nvm.uninstall is destructive — skipped"
}

test_node_version_rc_reads_value() {
  echo "18.17.1" > "$NVM_TEST_DIR/.nvmrc"
  expect "$(nvm.node.version.rc)" to.equal "18.17.1"
}

test_node_version_rc_empty_when_missing() {
  rm -f "$NVM_TEST_DIR/.nvmrc"
  expect "$(nvm.node.version.rc)" to.equal ""
}

test_node_current_version_matches_pattern() {
  local version
  version="$(nvm.node.version.current)"
  expect "$version" to.match "^v[0-9]+\\.[0-9]+\\.[0-9]+"
}

test_node_install_and_use_lazy() {
  expect.run "nvm.node.install 18.17.1" to.return "0"
  expect.run "nvm.node.use 18.17.1" to.return "0"
}

test_node_ensure_from_rc() {
  echo "18.17.1" > "$NVM_TEST_DIR/.nvmrc"
  nvm.node.ensure
  expect "$?" to.equal "0"
}

test_node_ensure_missing_version_errors() {
  rm -f "$NVM_TEST_DIR/.nvmrc"
  expect.run "nvm.node.ensure" to.fail.with 1 "No version specified"
}

test_node_version_is_installed_check() {
  nvm.node.install 18.17.1
  expect.run "nvm.node.version.is_installed 18.17.1" to.return "0"
}
