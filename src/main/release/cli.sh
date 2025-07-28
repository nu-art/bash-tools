#!/bin/bash
set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/steps.sh"

RUN_TESTS=true
RUN_BUNDLE=true
RUN_PUBLISH=true
RUN_BUMP=true
RUN_COMMIT=true
BUMP_TYPE="patch"

for arg in "$@"; do
  case "$arg" in
      --help|-h)
        echo "Usage: release.sh [options]"
        echo ""
        echo "Options:"
        echo "  --skip-tests        Skip the test phase"
        echo "  --skip-bundle       Skip the bundling phase"
        echo "  --skip-publish      Skip the GitHub publish phase"
        echo "  --skip-bump         Skip version bumping"
        echo "  --skip-commit       Skip committing the bumped version"
        echo "  --bump=<type>       Version bump type (patch, minor, major). Default: patch"
        echo "  --help, -h          Show this help message"
        exit 0
        ;;

    --skip-tests) RUN_TESTS=false ;;
    --skip-bundle) RUN_BUNDLE=false ;;
    --bundle-only)
      RUN_TESTS=false
      RUN_PUBLISH=false
      RUN_BUMP=false
      RUN_COMMIT=false
      ;;
    --tests-only)
      RUN_BUNDLE=false
      RUN_PUBLISH=false
      RUN_BUMP=false
      RUN_COMMIT=false
      ;;
    --skip-publish) RUN_PUBLISH=false; RUN_COMMIT=false ;;
    --skip-bump) RUN_BUMP=false ;;
    --skip-commit) RUN_COMMIT=false ;;
    --bump=*) BUMP_TYPE="${arg#*=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if $RUN_TESTS; then
  echo "🚀 Running test phase..."
  release.run_tests "$@"
else
  echo "⚠️  Skipping tests (--skip-tests)"
fi

if $RUN_BUNDLE; then
  echo "📦 Running bundling phase..."
  release.bundle
fi

if $RUN_PUBLISH; then
  echo "📤 Running publish phase..."
  release.publish_github
else
  echo "⚠️  Skipping GitHub publish (--skip-publish)"
fi

if $RUN_BUMP; then
  echo "🔧 Running version bump phase..."
  release.tag_current_version
  release.bump_version "$BUMP_TYPE"
else
  echo "⚠️  Skipping version bump (--skip-bump)"
fi

if $RUN_COMMIT; then
  echo "📌 Running commit phase..."
  release.commit_version
else
  echo "⚠️  Skipping version commit (--skip-commit)"
fi
