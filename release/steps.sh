#!/bin/bash

RELEASE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MAIN_ROOT="$RELEASE_ROOT/../src/main"
DIST_DIR="$RELEASE_ROOT/../dist"
version_file="$RELEASE_ROOT/../VERSION"

source "$MAIN_ROOT/tools/file.sh"
source "$MAIN_ROOT/tools/version.sh"
source "$MAIN_ROOT/tools/git.sh"
source "$MAIN_ROOT/core/logger.sh"

release.check(){
  echo "RELEASE_ROOT: ${RELEASE_ROOT}"
  echo "MAIN_ROOT: ${MAIN_ROOT}"
  echo "DIST_DIR: ${DIST_DIR}"
  echo "\$0: $0"
  echo "Caller PWD: $PWD"
  echo "pwd: $(pwd)"
}

release.run_tests() {
  bash "$MAIN_ROOT/bash-it/cli.sh" "$@"
}

release.bundle() {
  bash "$MAIN_ROOT/bundler/bundle.sh" --source "$MAIN_ROOT"
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

  mapfile -t artifacts < <(find "$DIST_DIR" -type f)
  if [[ ${#artifacts[@]} -eq 0 ]]; then
    log.error "No artifacts found to publish in $DIST_DIR"
    exit 1
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
  cp "$RELEASE_ROOT/integration.sh" "$DIST_DIR/integration.sh"
}

release.commit_version() {
  local version
  version="$(version.get "$version_file")"

  log.info "🔐 Committing version bump for v$version"
  git.commit "release: v$version"
  git.tag "v$version"
  git.push
}
