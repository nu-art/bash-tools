#!/bin/bash

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAIN_DIR="$DIR"

# Define which files to bundle from the project
source "${DIR}/bash-it/expect.sh"
source "${DIR}/core/logger.sh"
source "${DIR}/tools/array.sh"
source "${DIR}/tools/string.sh"
source "${DIR}/tools/time.sh"
source "${DIR}/tools/version.sh"
source "${DIR}/file-system/folder.sh"
source "${DIR}/file-system/navigation.sh"
