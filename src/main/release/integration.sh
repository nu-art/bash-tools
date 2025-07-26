#!/bin/bash

# shellcheck disable=SC1090
bash <(curl -fsSL https://github.com/nu-art/bash-tools/releases/latest/download/bundle.loader.sh) -b tools
string.join "-" hello world
