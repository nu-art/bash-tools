#!/bin/bash

## Bundle: tools
## Description: Shared Bash utilities (array, string, time, file-system, logger)

MAIN_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

source "${MAIN_ROOT}/tools/array.sh"
source "${MAIN_ROOT}/tools/string.sh"
source "${MAIN_ROOT}/tools/time.sh"
source "${MAIN_ROOT}/file-system/folder.sh"
source "${MAIN_ROOT}/file-system/navigation.sh"
source "${MAIN_ROOT}/core/logger.sh"


