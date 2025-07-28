#!/bin/bash

source "${MAIN_SOURCE_FOLDER}/tools/version.sh"

before_each() {
  ORIG_DIR="$(pwd)"
  mkdir -p .tmp-version-dir
  cd .tmp-version-dir || exit 2
}

after_each() {
  cd "$ORIG_DIR" || exit 2
  rm -rf .tmp-version-dir
}

test_version_get_success() {
  echo "1.2.3" > .tmp-version
  expect "$(version.get .tmp-version)" to.equal "1.2.3"
}

test_version_get_default_file() {
  echo "0.9.1" > VERSION
  expect "$(version.get)" to.equal "0.9.1"
}

test_version_get_invalid_format() {
  echo "v1.2" > .tmp-version
  expect.run "version.get .tmp-version" to.fail.with 2 "Invalid version format"
}

test_version_get_missing_file() {
  expect.run "version.get .missing" to.fail.with 2 "Version file not found"
}

test_version_set_and_get() {
  version.set "2.4.6" .tmp-version
  expect "$(cat .tmp-version)" to.equal "2.4.6"
  expect "$(version.get .tmp-version)" to.equal "2.4.6"
}

test_version_set_default_file() {
  version.set "3.3.3"
  expect "$(cat VERSION)" to.equal "3.3.3"
  expect "$(version.get)" to.equal "3.3.3"
}

test_version_bump_patch() {
  expect "$(version.bump 1.2.3 patch)" to.equal "1.2.4"
}

test_version_bump_minor() {
  expect "$(version.bump 1.2.3 minor)" to.equal "1.3.0"
}

test_version_bump_major() {
  expect "$(version.bump 1.2.3 major)" to.equal "2.0.0"
}

test_version_bump_invalid_type() {
  expect.run "version.bump 1.2.3 unknown" to.fail.with 2 "Unknown bump type"
}

test_version_checkMin_less() {
  expect "$(version.checkMin 1.2.3 2.0.0)" to.equal "true"
}

test_version_checkMin_equal() {
  expect "$(version.checkMin 1.2.3 1.2.3)" to.equal ""
}

test_version_checkMin_greater() {
  expect "$(version.checkMin 2.1.0 1.9.9)" to.equal ""
}
