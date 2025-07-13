#!/bin/bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${REPO_ROOT}/release/steps.sh"

RUN_TESTS=true
RUN_BUNDLE=true
RUN_BUMP=true
BUMP_TYPE="patch"

for arg in "$@"; do
  case "$arg" in
    --skip-tests) RUN_TESTS=false ;;
    --skip-bundle) RUN_BUNDLE=false ;;
    --skip-bump) RUN_BUMP=false ;;
    --bump=*) BUMP_TYPE="${arg#*=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if $RUN_TESTS; then
  echo "🚀 Running test phase..."
  release.run_tests
else
  echo "⚠️  Skipping tests (--skip-tests)"
fi

if $RUN_BUNDLE; then
  echo "📦 Running bundling phase..."
  release.bundle
else
  echo "⚠️  Skipping bundling (--skip-bundle)"
fi

if $RUN_BUMP; then
  echo "🔧 Running version bump phase..."
  release.bump_version "${BUMP_TYPE}"
else
  echo "⚠️  Skipping version bump (--skip-bump)"
fi
