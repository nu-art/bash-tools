#!/bin/bash

BUNDLER_NESTED_TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${BUNDLER_NESTED_TEST_DIR}/base.sh"

function nested_func() {
  echo "Nested logic"
}

