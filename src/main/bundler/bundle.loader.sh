#!/bin/bash
set -e

## @function: bundle.loader
##
## @description: Downloads and loads one or more named bundles from a GitHub release.
## Uses local cache unless --force is specified or cache is missing.
##
## @param --bundle value    (-b) (required, repeatable) One or more bundle names to load
## @param --version value   (-v) (optional) Specific version to load (default: latest)
## @param --force           (-f) (optional) Force re-download even if cache exists

REPO="nu-art/bash-tools"
BUNDLE_NAMES=()
VERSION="latest"
FORCE_DOWNLOAD=false
REMAINING_ARGS=()

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    --sh-repo|-sh-r)
      REPO="$2"
      shift 2
      ;;
    --sh-bundle|-sh-b)
      BUNDLE_NAMES+=("$2")
      shift 2
      ;;
    --sh-version|-sh-v)
      VERSION="$2"
      shift 2
      ;;
    --sh-force|-sh-f)
      FORCE_DOWNLOAD=true
      shift
      ;;

# Bellow params will be deprecated in future versions
    --repo|-r)
      REPO="$2"
      echo "avoid using --repo/-r, use --sh-repo/-sh-r instead"
      shift 2
      ;;
    --bundle|-b)
      BUNDLE_NAMES+=("$2")
      echo "avoid using --bundle/-b, use --sh-bundle/-sh-b instead"
      shift 2
      ;;
    --version|-v)
      VERSION="$2"
      echo "avoid using --version/-v, use --sh-version/-sh-v instead"
      shift 2
      ;;
    --force|-f)
      FORCE_DOWNLOAD=true
      echo "avoid using --force/-f, use --sh-force/-sh-f instead"
      shift
      ;;
    *) # collect remaining
      REMAINING_ARGS+=("$1")
      shift
      ;;
  esac
done

[[ ${#BUNDLE_NAMES[@]} -eq 0 ]] && {
  echo "❌ Missing required parameter: --bundle" >&2
  exit 1
}

CACHE_DIR="$PWD/.cache/bash-tools"
mkdir -p "$CACHE_DIR"
BASE_URL=${BASE_URL:-"https://github.com/${REPO}/releases"}

#echo "Running bundle: $BUNDLE_NAME v$BUNDLE_VERSION"

for BUNDLE_NAME in "${BUNDLE_NAMES[@]}"; do
  ASSET="bundle.${BUNDLE_NAME}.sh"
  CACHE_PATH="${CACHE_DIR}/${ASSET}"

  [[ "$VERSION" == "latest" ]] &&
    URL="$BASE_URL/latest/download/${ASSET}" ||
    URL="$BASE_URL/download/v${VERSION}/${ASSET}"

  if [[ "$FORCE_DOWNLOAD" = true || ! -f "$CACHE_PATH" ]]; then
    echo "🌐 Downloading $ASSET ($VERSION)..."

    if curl -fsSL --retry 2 "$URL" -o "${CACHE_PATH}.tmp"; then
      mv "${CACHE_PATH}.tmp" "$CACHE_PATH"
      echo "✅ Bundle saved to: $CACHE_PATH"

    else
      echo "⚠️  Failed to download. Trying to use cached version..."

      if [[ ! -f "$CACHE_PATH" ]]; then
        echo "❌ No cached bundle available for $BUNDLE_NAME" >&2
        exit 1
      fi
    fi
  else
    echo "📆 Using cached bundle: $CACHE_PATH"
  fi

  case "$BUNDLE_NAME" in
    lib.*)
      echo "📆 Sourcing: $CACHE_PATH"
      source "$CACHE_PATH"
    ;;
    *)
      echo "📆 Bashing: $CACHE_PATH ${REMAINING_ARGS[@]}"
      bash "$CACHE_PATH" "${REMAINING_ARGS[@]}"
    ;;
  esac
done
