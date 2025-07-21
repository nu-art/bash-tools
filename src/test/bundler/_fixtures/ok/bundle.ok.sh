#!/bin/bash

BUNDLER_TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${BUNDLER_TEST_DIR}/common.sh"

main() {
  echo "Hello from OK"
}
main

