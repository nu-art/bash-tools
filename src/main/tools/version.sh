#!/bin/bash

## @function: version.get(file?)
## @description: Read a version from file (default: VERSION), validate format
## @return: version string like 1.2.3
version.get() {
  local versionFile="${1:-VERSION}"
  [[ ! -f "$versionFile" ]] && echo "[ERROR] Version file not found: $versionFile" >&2 && return 2

  local version
  version=$(<"$versionFile")
  if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
    echo "[ERROR] Invalid version format: $version" >&2
    return 2
  fi

  echo "$version"
}

## @function: version.set(version, file?)
## @description: Write the given version to file (default: VERSION)
## @param: version - the version string
## @param: file - optional target file
version.set() {
  local version="$1"
  local versionFile="${2:-VERSION}"
  echo "$version" > "$versionFile"
}

## @function: version.bump(currentVersion, type)
## @description: Promote a version by major/minor/patch
## @return: new version string
version.bump() {
  local current="$1"
  local type="$2"

  IFS='.' read -r major minor patch <<< "$current"
  major=${major:-0}
  minor=${minor:-0}
  patch=${patch:-0}

  case "$type" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
    *) echo "[ERROR] Unknown bump type: $type" >&2; return 2 ;;
  esac

  echo "${major}.${minor}.${patch}"
}

## @function: version.checkMin(current, required)
## @description: Check if current version is lower than required
## @return: true if current < required, nothing otherwise
version.checkMin() {
  local current="$1"
  local required="$2"

  IFS='.' read -ra curParts <<< "$current"
  IFS='.' read -ra reqParts <<< "$required"

  local len=${#reqParts[@]}
  for ((i = 0; i < len; i=i+1)); do
    local curVal=${curParts[i]:-0}
    local reqVal=${reqParts[i]:-0}

    if ((curVal < reqVal)); then echo true; return; fi
    if ((curVal > reqVal)); then return; fi
  done
}
