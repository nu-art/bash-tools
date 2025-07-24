#!/bin/bash
set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../main/core/importer.sh"
import "../../main/doc/generator.sh"

## @function: test.doc_generator_outputs_expected_docs
##
## @description: Runs doc.generate on a sample fixture and asserts that expected doc lines appear.

test_doc_generator_outputs_expected_docs() {
  local output
  output=$(doc.generate ./src/test/docs/fixtures/sample.sh)
  expect "$output" to.contain "🔧 array.contains"
  expect "$output" to.contain "Check if an item is in a list"
  expect "$output" to.contain "Params:"
  expect "$output" to.contain "\$1  The item to search for"
  expect "$output" to.contain "\$@  The list to search in"
  expect "$output" to.contain "Returns:"
  expect "$output" to.contain "true if contained, null otherwise"
}








