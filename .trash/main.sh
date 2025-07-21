#!/bin/bash

_ROOT="$(cd "$(dirname "${PWD}/$0")" && pwd)"


echo "🟢 main script:"
echo "🧾 BASH_SOURCE[0] = ${BASH_SOURCE[0]}"
echo "📛 \$0              = $0"
echo "📂 PWD             = $PWD"
echo "📍 RELEASE_ROOT    = $(cd "$(dirname "${PWD}/$0")" && pwd)"
echo -------

echo "🟢 Running with bash:"
bash ${_ROOT}/test-context.sh

echo ""
echo "🟡 Sourcing the script:"
source ${_ROOT}/test-context.sh
