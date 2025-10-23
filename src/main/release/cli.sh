#!/bin/bash
set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "./steps.sh"

log.debug "Running Bundle: $BUNDLE_NAME v$BUNDLE_VERSION"

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

    --dry-run) DRY_RUN=true ;;

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

$DRY_RUN && echo "🧪 DRY RUN MODE ENABLED — no commands will be executed"

if $RUN_TESTS; then
  [[ ! $DRY_RUN ]] &&  release.run_tests "$@"
else
  echo "⚠️  Skipping tests (--skip-tests)"
fi

if [[ $RUN_COMMIT ]] && [[ "$BUMP_TYPE" != "patch" ]];  then
  [[ ! $DRY_RUN ]] && release.bump_version "$BUMP_TYPE"
fi

if $RUN_COMMIT && ! git.is_clean; then
  [[ ! $DRY_RUN ]] && release.commit_dirty_repo_before_release
else
  echo "⚠️  Skipping Pushing local changes before releasing (--skip-commit)"
fi

if $RUN_BUNDLE; then
  [[ ! $DRY_RUN ]] && release.bundle
fi

if $RUN_PUBLISH; then
  [[ ! $DRY_RUN ]] && release.publish_github
else
  echo "⚠️  Skipping GitHub publish (--skip-publish)"
fi

if $RUN_BUMP; then
  [[ ! $DRY_RUN ]] && release.tag_current_version
else
  echo "⚠️  Skipping version bump (--skip-bump)"
fi

if [[ $RUN_COMMIT ]];  then
  [[ ! $DRY_RUN ]] && release.bump_version "patch"
  [[ ! $DRY_RUN ]] && release.commit_version_bump
else
  echo "⚠️  Skipping version commit (--skip-commit)"
fi
