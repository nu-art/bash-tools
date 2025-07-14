#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLER_ROOT="${1:-$DIR}"

source "${DIR}/../tools/string.sh"
source "${DIR}/../tools/array.sh"
source "${DIR}/../tools/file.sh"
source "${DIR}/../file-system/folder.sh"
source "${DIR}/../core/logger.sh"

BUNDLE_PATTERN="bundle.*.sh"

# Discover the repo root by looking for .git or VERSION
discover_repo_root() {
  local dir="$BUNDLER_ROOT"
  while [[ "$dir" != "/" ]]; do
    [[ -d "$dir/.git" || -f "$dir/VERSION" ]] && echo "$dir" && return
    dir="$(dirname "$dir")"
  done
  log.error "Unable to discover REPO_ROOT (missing .git or VERSION marker)"
  exit 1
}

REPO_ROOT=$(file.path "${REPO_ROOT:-$(discover_repo_root)}")
MAIN_ROOT="$REPO_ROOT/src/main"
DIST_DIR="$REPO_ROOT/dist"
folder.create "$DIST_DIR"

echo "REPO_ROOT = ${REPO_ROOT}"
echo "MAIN_ROOT = ${MAIN_ROOT}"
echo "DIST_DIR  = ${DIST_DIR}"
echo
log.info "📦 Starting bundling process"

# Create the DIST_FILE before collecting sources
create_bundle_file() {
  local entrypoint="$1"
  local rel_path="$2"
  local dist_file="$3"

  {
    echo "#!/bin/bash"
    echo "## @entry: $rel_path"
    echo "## @version: $(cat "$REPO_ROOT/VERSION")"
    echo "## @generated: $(date +"%Y-%m-%d %H:%M:%S")"
    echo
  } > "$dist_file"
}

# Collect and inline sourced files recursively, deepest first
collect_sources() {
  local file="$1"
  local dir abs_path rel_path

  # Prevent duplicate inclusion
  [[ -n "${included[$file]}" ]] && return
  included["$file"]=1

  dir="$(dirname "$file")"

  while read -r line; do
    [[ "$line" =~ ^source\ \"\$\{[A-Za-z_][A-Za-z0-9_]*\}/(.+\.sh)\"$ ]] || continue
    suffix="${BASH_REMATCH[1]}"
    abs_path="$(file.path "${dir}/${suffix}")"

    if [[ ! -f "$abs_path" ]]; then
      log.error "Missing sourced file: '$suffix' (resolved from: $file)"
      exit 1
    fi

    collect_sources "$abs_path"
  done < "$file"

  rel_path="${file#"${MAIN_ROOT}/"}"
  log.info "  ➕ $file"
  {
    echo "## --- FILE: $rel_path ---"
    grep -vE '^\s*source\s+\\?"?\\$\{[A-Za-z_][A-Za-z0-9_]*}/.+\\.sh\\?"?$' "$file" | grep -v '^#! */bin/bash'
    echo
  } >> "$DIST_FILE"
}

# Find all bundle entrypoints
mapfile -t bundle_entrypoints < <(find "$BUNDLER_ROOT" -type f -name "$BUNDLE_PATTERN")
array.map bundle_entrypoints bundle_entrypoints file.path

log.debug "Found ${#bundle_entrypoints[@]} bundle entrypoint(s):"
for ep in "${bundle_entrypoints[@]}"; do
  log.debug " - $ep"
done

# Process each entrypoint
for entrypoint in "${bundle_entrypoints[@]}"; do
  [[ -f "$entrypoint" ]] || continue
  name=$(basename "$entrypoint")
  bundle_name="${name#bundle.}"
  bundle_name="${bundle_name%.sh}"
  DIST_FILE="$DIST_DIR/bundle.${bundle_name}.sh"

  log.info "🔍 Bundling: $entrypoint → $DIST_FILE"
  rel_path="${entrypoint#"$MAIN_ROOT"/}"

  declare -A included=()
  create_bundle_file "$entrypoint" "$rel_path" "$DIST_FILE"
  collect_sources "$entrypoint"
  chmod +x "$DIST_FILE"
  log.info "✅ Created $DIST_FILE"
done