#!/bin/bash

## Bundle: bash-it
## Description: Minimal TAP test runner and `expect` assertion framework

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$DIR"

source "${ROOT}/expect.sh"
source "${ROOT}/runner.sh"
source "${ROOT}/cli.sh"


