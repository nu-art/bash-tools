#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "../core/logger.sh"
import "../tools/error.sh"
import "../tools/string.sh"
import "../tools/array.sh"
import "../tools/file.sh"
import "../file-system/folder.sh"


## @function: bundle.run(source, dist)
##
## @description: Entry point for bundling all entrypoints matching bundle.*.sh in a given folder.
##
## @param: $1 - Source root
## @param: $2 - Dist folder for bundled files
bundler.run() {
  bundler.create_file() {
    local entrypoint="$1"
    local rel_path="$2"
    local dist_file="$3"
    local version
    version="$(cat "$REPO_ROOT/VERSION")"
    {
      echo "#!/bin/bash"
      echo "## @entry: $rel_path"
      echo "## @version: $version"
      echo "## @generated: $(date +"%Y-%m-%d %H:%M:%S")"
      echo "log.verbose \"Running: $entrypoint\""
      echo "log.debug \"Version: $version\""
      echo
    } > "$dist_file"
  }

  bundler.collect_sources() {
    local file="$1"
    local dist_file="$2"
    local dir abs_path rel_path

    [[ -n "${included[$file]}" ]] && return
    included["$file"]=1

    dir="$(dirname "$file")"

    while read -r line; do
      if [[ "$line" =~ ^import\ +\"([^\"]+\.sh)\"$ ]]; then
        local import_path="${BASH_REMATCH[1]}"
        abs_path="$(file.path "${dir}/${import_path}")"

      elif [[ $line =~ ^source\ +\"\$\{[A-Za-z_][A-Za-z0-9_]*\}/(.+\.sh)\"$ ]]; then
        local suffix="${BASH_REMATCH[1]}"
        abs_path="$(file.path "${dir}/${suffix}")"

      elif [[ $line =~ ^source\ +\"\$\(\s*cd.*pwd\s*\)/(.+\.sh)\"$ ]]; then
        local suffix="${BASH_REMATCH[1]}"
        abs_path="$(file.path "${dir}/${suffix}")"

      else
        continue
      fi

      if [[ ! -f "$abs_path" ]]; then
        log.error "Missing sourced file: '$suffix' (resolved from: $file)"
        exit 1
      fi

      bundler.collect_sources "$abs_path" "$dist_file"
    done < "$file"

    rel_path="${file#"${SOURCE_ROOT}/"}"
    log.info "  ➕ $file"
    {
      echo "## --- FILE: $rel_path ---"
      grep -vE '^\s*(source|import)\s+".*\.sh' "$file" |
        grep -v '^#! */bin/bash' |
          grep -vE '^[A-Za-z_][A-Za-z0-9_]*=\$\(cd .*\bdirname\b.*BASH_SOURCE\[0\].*\)'
      echo
    } >> "$dist_file"
  }

  BUNDLE_PATTERN="bundle.*.sh"
  REPO_ROOT="${REPO_ROOT:-$(folder.repo_root)}"

  local SOURCE_ROOT="${1:-$(file.path "$REPO_ROOT/src/main")}"
  local DIST_DIR="${2:-$(file.path "$REPO_ROOT/dist")}"

  folder.create "$DIST_DIR"

  log.info "📦 Starting bundling process"
  log.debug "REPO_ROOT = $REPO_ROOT"
  log.debug "SOURCE_ROOT = $SOURCE_ROOT"
  log.debug "DIST_DIR = $DIST_DIR"

  mapfile -t bundle_entrypoints < <(find "$SOURCE_ROOT" -type f -name "$BUNDLE_PATTERN")
  array.map bundle_entrypoints bundle_entrypoints file.path

  log.debug "Found ${#bundle_entrypoints[@]} bundle entrypoint(s):"
  for ep in "${bundle_entrypoints[@]}"; do
    log.debug " - $ep"
  done

  for entrypoint in "${bundle_entrypoints[@]}"; do
    [[ -f "$entrypoint" ]] || continue

    name=$(basename "$entrypoint")
    bundle_name="${name#bundle.}"
    bundle_name="${bundle_name%.sh}"
    DIST_FILE="$DIST_DIR/bundle.${bundle_name}.sh"

    log.info "🔍 Bundling: $entrypoint → $DIST_FILE"
    rel_path="${entrypoint#"$SOURCE_ROOT"/}"

    declare -A included=()
    bundler.create_file "$entrypoint" "$rel_path" "$DIST_FILE"
    bundler.collect_sources "$entrypoint" "$DIST_FILE"
    chmod +x "$DIST_FILE"
    log.info "✅ Created $DIST_FILE"
  done
}

