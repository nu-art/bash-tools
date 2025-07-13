#!/bin/bash

## Bundle: full
## Description: Full bash-it runtime including tools and colors

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT="$DIR"

source "$ROOT/tools/bundle.tools.sh"
source "$ROOT/bash-it/bundle.bash-it.sh"
source "$ROOT/consts/colors.sh"
