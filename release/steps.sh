#!/bin/bash

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_ROOT="$RELEASE_ROOT/../src/main"

release.run_tests() {
  bash "${MAIN_ROOT}/bash-it/tests-runner.sh"
}

release.bundle() {
  bash "${MAIN_ROOT}/bundler/bundle.sh" "${MAIN_ROOT}"
}

release.bump_version() {
  local bump_type="${1:-patch}"
  local current
  local next

  source "${MAIN_ROOT}/tools/version.sh"

  local version_file="${RELEASE_ROOT}/../VERSION"
  current="$(version.get "$version_file")"
  next="$(version.bump "$current" "$bump_type")"

  version.set "$next" "$version_file"
  echo "🔖 Version promoted: $current → $next"
}


