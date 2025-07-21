#!/bin/bash

RELEASE_ROOT="$(cd "$(dirname "${PWD}/$0")" && pwd)"
echo "RELEASE_ROOT: ${RELEASE_ROOT}"
echo "\$0: $0"
echo "Caller PWD: $PWD"

MAIN_ROOT="$RELEASE_ROOT/../src/main"
DIST_DIR="$RELEASE_ROOT/../dist"
version_file="$RELEASE_ROOT/../VERSION"

source "$MAIN_ROOT/tools/version.sh"
source "$MAIN_ROOT/tools/git.sh"
source "$MAIN_ROOT/core/logger.sh"

release.run_tests() {
  bash "$MAIN_ROOT/bash-it/tests-runner.sh" "$@"
}

release.bundle() {
  bash "$MAIN_ROOT/bundler/bundle.sh" "$MAIN_ROOT"
}

release.bump_version() {
  local bump_type="${1:-patch}"
  local current
  local next

  current="$(version.get "$version_file")"
  next="$(version.bump "$current" "$bump_type")"

  version.set "$next" "$version_file"
  echo "🔖 Version promoted: $current → $next"
}

release.publish_github() {
  local version
  version="$(version.get "$version_file")"

  if ! command -v gh >/dev/null 2>&1; then
    log.error "GitHub CLI (gh) is not installed or not in PATH."
    exit 1
  fi

  log.info "🚀 Publishing v$version to GitHub..."

  mapfile -t bundles < <(find "$DIST_DIR" -type f -name "bundle.*.sh")
  if [[ ${#bundles[@]} -eq 0 ]]; then
    log.error "No bundles found to publish in $DIST_DIR"
    exit 1
  fi

  log.info "📦 Bundles to publish:"
  for bundle in "${bundles[@]}"; do
    log.info " - $bundle"
  done

  gh release create "v$version" \
    "${bundles[@]}" \
    --title "v$version" \
    --notes "Automated release of bash-utils v$version"

  log.info "✅ Release v$version published successfully."
}

release.commit_version() {
  local version
  version="$(version.get "$version_file")"

  log.info "🔐 Committing version bump for v$version"
  git.commit "release: v$version"
  git.tag "v$version"
  git.push
}
