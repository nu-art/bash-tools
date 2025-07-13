#!/bin/bash
set -e

## @function: bundle.loader
##
## @description: Downloads and loads a named bundle from a GitHub release.
## Can fallback to cached version if offline.
##
## @param --bundle=name       (required) The name of the bundle to load
## @param --target=path       (required) Where to cache/load the bundle locally
## @param --version=version   (optional) Specific version to load (default: latest)

BUNDLE_NAME=""
VERSION="latest"
TARGET=""
REPO="nu-art/bash-tools"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --bundle=*) BUNDLE_NAME="${arg#*=}" ;;
    --version=*) VERSION="${arg#*=}" ;;
    --target=*) TARGET="${arg#*=}" ;;
    *) echo "❌ Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

[[ -z "$BUNDLE_NAME" || -z "$TARGET" ]] && {
  echo "❌ Missing required parameters --bundle and --target" >&2
  exit 1
}

ASSET="bundle.${BUNDLE_NAME}.sh"
CACHE_PATH="$TARGET"

# Construct GitHub download URL
BASE_URL="https://github.com/${REPO}/releases"
[[ "$VERSION" == "latest" ]] &&
  URL="$BASE_URL/latest/download/${ASSET}" ||
  URL="$BASE_URL/download/v${VERSION}/${ASSET}"

# Try downloading
echo "🌐 Downloading $ASSET ($VERSION)..."
if curl -fsSL --retry 2 "$URL" -o "${CACHE_PATH}.tmp"; then
  mv "${CACHE_PATH}.tmp" "$CACHE_PATH"
  echo "✅ Bundle saved to: $CACHE_PATH"
else
  echo "⚠️  Failed to fetch bundle. Using cached version (if available)..."
  if [[ ! -f "$CACHE_PATH" ]]; then
    echo "❌ No cached bundle found at $CACHE_PATH"
    exit 1
  fi
fi

# Load the bundle
source "$CACHE_PATH"
