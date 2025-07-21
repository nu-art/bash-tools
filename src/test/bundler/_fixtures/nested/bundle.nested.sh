#!/bin/bash

BUNDLER_TEST_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${BUNDLER_TEST_DIR}/nested.sh"
echo "From root"

