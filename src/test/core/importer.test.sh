#!/bin/bash

## Test Suite: importer.test.sh
## Description: Validates import() utility - idempotency, error handling, and resolution

IMPORT_TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${IMPORT_TEST_DIR}/../../main/core/importer.sh"

before_each() {
  TMP_IMPORT_TEST_DIR="${IMPORT_TEST_DIR}/.tmp-import-test"
  mkdir -p "$TMP_IMPORT_TEST_DIR"
  __loaded_files=()
}

after_each() {
  rm -rf "$TMP_IMPORT_TEST_DIR"
  unset test_import_loaded
  __loaded_files=()
}

test_import_loads_script() {
  echo '#!/bin/bash' > "${TMP_IMPORT_TEST_DIR}/simple.sh"
  echo 'test_import_loaded=true' >> "${TMP_IMPORT_TEST_DIR}/simple.sh"
  echo $(pwd)
  import "./.tmp-import-test/simple.sh"
  expect "$test_import_loaded" to.equal "true"
}

test_import_idempotent() {
  echo '#!/bin/bash' > "${TMP_IMPORT_TEST_DIR}/simple.sh"
  echo 'test_import_loaded=true' >> "${TMP_IMPORT_TEST_DIR}/simple.sh"

  import "./.tmp-import-test/simple.sh"
  test_import_loaded="overwritten"

  import "./.tmp-import-test/simple.sh"
  expect "$test_import_loaded" to.equal "overwritten"
}

test_import_directory_should_fail() {
  mkdir -p "${TMP_IMPORT_TEST_DIR}/nested-dir"

  pushd "$IMPORT_TEST_DIR" > /dev/null || exit 1

  import.__stack_trace_index 3
  expect.run "import './.tmp-import-test/nested-dir'" to.fail.with 1 "is a directory"
  popd > /dev/null || exit 1
}

test_import_missing_file_should_fail() {
  expect.run "import './.tmp-import-test/missing-file.sh'" to.fail.with 1 "does not exist"
}
