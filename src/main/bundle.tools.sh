#!/bin/bash

## Bundle: tools
## Description: Shared Bash utilities (array, string, time, file-system, logger)

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$DIR"

source "$ROOT/tools/array.sh"
source "$ROOT/tools/string.sh"
source "$ROOT/tools/time.sh"
source "$ROOT/tools/file-system/folder.sh"
source "$ROOT/tools/file-system/navigation.sh"
source "$ROOT/core/logger.sh"


