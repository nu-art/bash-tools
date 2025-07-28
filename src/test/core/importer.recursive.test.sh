#!/bin/bash

## Test Suite: importer.recursive.test.sh
## Description: Validates nested/recursive import behavior and load-once protection

before_each() {
  TMP_IMPORT_RECURSION_DIR="${TEST_DIST_FOLDER}/.tmp-import-recursive"
  mkdir -p "$TMP_IMPORT_RECURSION_DIR"
  __loaded_files=()
}

after_each() {
  rm -rf "$TMP_IMPORT_RECURSION_DIR"
  unset imported_inner
  unset imported_outer
  __loaded_files=()
}

test_recursive_imports_only_load_once() {
  echo '#!/bin/bash' > "$TMP_IMPORT_RECURSION_DIR/inner.sh"
  echo 'imported_inner="yes"' >> "$TMP_IMPORT_RECURSION_DIR/inner.sh"

  echo '#!/bin/bash' > "$TMP_IMPORT_RECURSION_DIR/outer.sh"
  echo 'import "./inner.sh"' >> "$TMP_IMPORT_RECURSION_DIR/outer.sh"
  echo 'imported_outer="yes"' >> "$TMP_IMPORT_RECURSION_DIR/outer.sh"

  import "$TMP_IMPORT_RECURSION_DIR/outer.sh"

  expect "$imported_inner" to.equal "yes"
  expect "$imported_outer" to.equal "yes"

  # overwrite and re-import to test idempotency
  imported_inner="overwritten"
  imported_outer="overwritten"

  import "$TMP_IMPORT_RECURSION_DIR/outer.sh"

  expect "$imported_inner" to.equal "overwritten"
  expect "$imported_outer" to.equal "overwritten"
}
