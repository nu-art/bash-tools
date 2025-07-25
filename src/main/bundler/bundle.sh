#!/bin/bash
set -e

BUNDLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${BUNDLER_DIR}/../tools/string.sh"
source "${BUNDLER_DIR}/../tools/array.sh"
source "${BUNDLER_DIR}/../tools/file.sh"
source "${BUNDLER_DIR}/../file-system/folder.sh"
source "${BUNDLER_DIR}/../core/logger.sh"

BUNDLE_PATTERN="bundle.*.sh"
REPO_ROOT="${REPO_ROOT:-$(folder.repo_root)}"
SOURCE_ROOT="$REPO_ROOT/src/main"
DIST_DIR="$REPO_ROOT/dist"

# Allow override via --source and --dist
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_ROOT="$(file.path "$2")"
      shift 2
      ;;
    --dist)
      DIST_DIR="$(file.path "$2")"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done


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

    collect_sources "$abs_path"
  done < "$file"

  rel_path="${file#"${SOURCE_ROOT}/"}"
  log.info "  ➕ $file"
  {
    echo "## --- FILE: $rel_path ---"
    grep -vE '^\s*(source|import)\s+.*\.sh' "$file" |
      grep -v '^#! */bin/bash' |
        grep -vE '^[A-Za-z_][A-Za-z0-9_]*=\$\(cd .*\bdirname\b.*BASH_SOURCE\[0\].*\)'

    echo
  } >> "$DIST_FILE"
}

folder.create "$DIST_DIR"

echo "REPO_ROOT = ${REPO_ROOT}"
echo "SOURCE_ROOT = ${SOURCE_ROOT}"
echo "DIST_DIR  = ${DIST_DIR}"
echo
log.info "📦 Starting bundling process"

# Find all bundle entrypoints
mapfile -t bundle_entrypoints < <(find "$SOURCE_ROOT" -type f -name "$BUNDLE_PATTERN")
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
  rel_path="${entrypoint#"$SOURCE_ROOT"/}"

  declare -A included=()
  create_bundle_file "$entrypoint" "$rel_path" "$DIST_FILE"
  collect_sources "$entrypoint"
  chmod +x "$DIST_FILE"
  log.info "✅ Created $DIST_FILE"
done
