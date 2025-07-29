#!/bin/bash

import "../file-system/folder.sh"
import "../tools/error.sh"
import "../tools/file.sh"
import "../tools/version.sh"
import "../tools/git.sh"
import "../core/logger.sh"
import "../bash-it/runner.sh"
import "../bundler/bundler.sh"



REPO_ROOT="${REPO_ROOT:-$(folder.repo_root)}"
_MAIN_ROOT="$REPO_ROOT/src/main"
_DIST_DIR="$REPO_ROOT/dist"

VERSION_FILE="${REPO_ROOT}/VERSION"
#  echo "RELEASE_ROOT: ${RELEASE_ROOT}"
#  echo "REPO_ROOT: ${REPO_ROOT}"
#  echo "_MAIN_ROOT: ${_MAIN_ROOT}"
#  echo "_DIST_DIR: ${_DIST_DIR}"
#  echo "\$0: $0"
#  echo "Caller PWD: $PWD"
#  echo "pwd: $(pwd)"
release.run_tests() {
  log.info "🚀 Running test phase..."
  tests.run
}

release.bundle() {
  log.info "📦 Running bundling phase..."

  folder.delete "$_DIST_DIR"
  bundler.run "$_MAIN_ROOT" "$_DIST_DIR"
}

release.tag_current_version() {
  local version
  version="$(version.get "$VERSION_FILE")"

  log.info "🔖 Tagging current version: v$version"
  git.tag "v$version"
  git.push
}

release.bump_version() {
  local bump_type="${1:-patch}"
  local current
  local next

  current="$(version.get "$VERSION_FILE")"
  next="$(version.bump "$current" "$bump_type")"

  version.set "$next" "$VERSION_FILE"
  log.info "🔖 Version promoted: $current → $next"
}

release.publish_github() {
  local version
  version="$(version.get "$VERSION_FILE")"

  if ! command -v gh >/dev/null 2>&1; then
    log.warning "Publishing v$version to GitHub"
    error.throw "GitHub CLI (gh) is not installed or not in PATH."
  fi

  log.info "🚀 Publishing v$version to GitHub from $_DIST_DIR... "

  mapfile -t artifacts < <(find "$_DIST_DIR" -type f)
  if [[ ${#artifacts[@]} -eq 0 ]]; then
    error.throw "No artifacts found to publish in $_DIST_DIR"
  fi

  log.info "📦 Files to publish:"
  for file in "${artifacts[@]}"; do
    log.info " - $file"
  done

  gh release create "v$version" \
    "${artifacts[@]}" \
    --title "v$version" \
    --notes "Automated release v$version"

  log.info "✅ Release v$version published successfully."
}

release.copy.integration_script() {
  cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/integration.sh" "$_DIST_DIR/integration.sh"
}

release.commit_version_bump() {
  local version
  version="$(version.get "$VERSION_FILE")"

  log.info "💾 Committing version bump: v$version"
  git.add
  git.commit "release: prepare v$version"
  git.push
}

release.commit_dirty_repo_before_release() {
  local version
  version="$(version.get "$VERSION_FILE")"

  log.info "💾 Committing dirty repo before releasing version: v$version"
  git.add
  git.commit "releasing v$version"
  git.push
}
