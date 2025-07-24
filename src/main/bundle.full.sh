#!/bin/bash

## Bundle: full
## Description: Full bash-it runtime including tools and colors

BUNDLE_FULL_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${BUNDLE_FULL_DIR}/bundle.tools.sh"
source "${BUNDLE_FULL_DIR}/bash-it/bundle.bash-it.sh"
