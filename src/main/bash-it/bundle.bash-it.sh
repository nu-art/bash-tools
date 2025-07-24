#!/bin/bash

## Bundle: bash-it
## Description: Minimal TAP test runner and `expect` assertion framework

BUNDLE_BASH_IT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${BUNDLE_BASH_IT_DIR}/expect.sh"
source "${BUNDLE_BASH_IT_DIR}/runner.sh"
source "${BUNDLE_BASH_IT_DIR}/cli.sh"
