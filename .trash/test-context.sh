#!/bin/bash

echo "🧾 BASH_SOURCE[0] = ${BASH_SOURCE[0]}"
echo "📛 \$0              = $0"
echo "📂 PWD             = $PWD"
echo "📍 RELEASE_ROOT    = $(cd "$(dirname "${PWD}/$0")" && pwd)"
echo -------