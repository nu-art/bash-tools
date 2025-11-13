#!/bin/bash

## Bundle: tools
## Description: Shared Bash utilities (array, string, time, file-system, logger)

BUNDLE_TOOLS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${BUNDLE_TOOLS_DIR}/tools/array.sh"
source "${BUNDLE_TOOLS_DIR}/tools/error.sh"
source "${BUNDLE_TOOLS_DIR}/tools/file.sh"
source "${BUNDLE_TOOLS_DIR}/tools/git.sh"
source "${BUNDLE_TOOLS_DIR}/tools/string.sh"
source "${BUNDLE_TOOLS_DIR}/tools/time.sh"
source "${BUNDLE_TOOLS_DIR}/tools/version.sh"
source "${BUNDLE_TOOLS_DIR}/tools/node/nvm.sh"
source "${BUNDLE_TOOLS_DIR}/file-system/folder.sh"
source "${BUNDLE_TOOLS_DIR}/file-system/navigation.sh"
source "${BUNDLE_TOOLS_DIR}/file-system/symlink.sh"
source "${BUNDLE_TOOLS_DIR}/core/logger.sh"
source "${BUNDLE_TOOLS_DIR}/ssl/ssl.sh"


