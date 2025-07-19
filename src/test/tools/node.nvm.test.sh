#!/bin/bash

# Test suite for src/main/tools/node/nvm.sh
# These tests run against the real environment and expect NVM and Node.js to be installed/configurable.
# Destructive tests (like uninstalling NVM) are skipped for safety.


DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/../../main/tools/node/nvm-tools.sh"

test_node__source_nvm_found() {
  node.__source_nvm
  expect "$?" to.equal "0"
}

test_node_ensure_nvm_found() {
  node.ensure_nvm
  expect "$?" to.equal "0"
}

test_node_install_nvm_already_installed() {
  node.install_nvm
  expect "$?" to.equal "0"
}

test_node_uninstall_nvm_skipped() {
  # Skipped for safety
  echo "SKIP: uninstalling NVM is destructive in a real environment"
}

test_node_version_reads_nvmrc() {
  local orig_nvmrc
  if [ -f .nvmrc ]; then orig_nvmrc=$(cat .nvmrc); fi
  echo "18.17.1" > .nvmrc
  expect "$(node.version)" to.equal "18.17.1"
  if [ -n "$orig_nvmrc" ]; then echo "$orig_nvmrc" > .nvmrc; else rm .nvmrc; fi
}

test_node_version_no_nvmrc() {
  local orig_nvmrc
  if [ -f .nvmrc ]; then orig_nvmrc=$(cat .nvmrc); rm .nvmrc; fi
  expect "$(node.version)" to.equal ""
  if [ -n "$orig_nvmrc" ]; then echo "$orig_nvmrc" > .nvmrc; fi
}

test_node_current() {
  local version
  version=$(node.current)
  expect "$version" to.match "^v[0-9]+\\.[0-9]+\\.[0-9]+"
}

test_node_install_and_use() {
  # This will install and use a specific version (safe if nvm is present)
  node.install 18.17.1
  expect "$?" to.equal "0"
  node.use 18.17.1
  expect "$?" to.equal "0"
}

test_node_ensure() {
  echo "18.17.1" > .nvmrc
  node.ensure
  expect "$?" to.equal "0"
  rm .nvmrc
} 