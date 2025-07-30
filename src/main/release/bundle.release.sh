#!/bin/bash

## Bundle: release
## Description: Bash tools release runner

BUNDLE_RELEASE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="${REPO_ROOT:-$(folder.repo_root)}"
SOURCE_ROOT="$REPO_ROOT/src/main"
DIST_DIR="$REPO_ROOT/dist"

source "${BUNDLE_RELEASE_DIR}/cli.sh" "$@"
