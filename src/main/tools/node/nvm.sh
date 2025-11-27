#!/bin/bash

import "../../core/logger.sh"
import "../../tools/error.sh"


## @function: nvm.default_version()
##
## @description: Default NVM version, overridable via $NVM_DEFAULT_VERSION
##
## @return: string
nvm.default_version() {
  echo "${NVM_DEFAULT_VERSION:-0.40.3}"
}


## @function: nvm.version()
##
## @description: Returns currently installed NVM version from package.json (if available)
##
## @return: version string or null
nvm.version() {
  local file="$HOME/.nvm/package.json"
  [[ -f "$file" ]] || return

  string.find "[0-9]+\.[0-9]+\.[0-9]+" "$(cat "$file")"
}

## @function: nvm.source()
##
## @description: Sources ~/.nvm/nvm.sh if not already sourced
##
## @return: exits 1 on failure
nvm.source() {
  if [[ -n "$__nvm_loaded" ]]; then
    return
  fi

  local nvm_script="$HOME/.nvm/nvm.sh"

  if [[ -s "$nvm_script" ]]; then
    # shellcheck disable=SC1090
    . "$nvm_script" --no-use
    __nvm_loaded=true
  fi

  command -v nvm >/dev/null || error.throw "Failed to source NVM from $nvm_script"
}


## @function: nvm.install(version?)
##
## @description: Installs NVM from GitHub if not already installed or outdated
##
## @param: version - optional (defaults to nvm.default_version)
## @return: exits 1 on failure
nvm.install() {
  local version="${1:-$(nvm.default_version)}"
  local current="$(nvm.version)"

  if [[ "$current" == "$version" ]]; then
    log.debug "[nvm.install] NVM v$version already installed"
    return
  fi

  log.verbose "nvm: expected version: $version  installed version: $current"
  log.debug "Current NVM version is $current, updating..."

  log.info "[nvm.install] Installing NVM v$version..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v$version/install.sh" | bash
  nvm.source
}


## @function: nvm.uninstall()
##
## @description: Uninstalls NVM and cleans up shell configs
nvm.uninstall() {
  log.info "[nvm.uninstall] Removing NVM and shell RC entries..."
  rm -rf "$HOME/.nvm"
  sed -i.bak '/NVM_DIR/d;/nvm.sh/d' "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
}


## @function: nvm.node.version.rc()
##
## @description: Reads Node.js version from .nvmrc (if exists)
##
## @return: version string or null
nvm.node.version.rc() {
  [[ -f .nvmrc ]] && cat .nvmrc
}


## @function: nvm.node.version.current()
##
## @description: Returns currently active Node.js version
##
## @return: version string or exits 1
nvm.node.version.current() {
  command -v node >/dev/null || error.throw "Node.js is not available"
  node -v
}


## @function: nvm.node.version.is_installed(version)
##
## @description: Checks if a specific Node.js version is installed in NVM
##
## @return: true if installed
nvm.node.version.is_installed() {
  local version="$1"
  [[ -z "$version" ]] && error.throw "Missing version to assert"

  [[ -d "$HOME/.nvm/versions/node/v$version" ]]
}


## @function: nvm.node.install(version)
##
## @description: Installs given Node.js version via NVM
nvm.node.install() {
  local version="$1"
  [[ -z "$version" ]] && version="$(nvm.node.version.rc)"
  [[ -z "$version" ]] && error.throw "No version specified and no .nvmrc found"

  if nvm.node.version.is_installed "$version"; then
    log.debug "[nvm.node.install] Node.js v$version already installed"
    return
  fi

  nvm.source
  nvm install "$version"
}


## @function: nvm.node.use(version)
##
## @description: Activates specified Node.js version
nvm.node.use() {
  local version="$1"

  [[ -z "$version" ]] && version="$(nvm.node.version.rc)"
  [[ -z "$version" ]] && error.throw "Missing version for Node.js use"

  local current_version="$(nvm.node.version.current | sed 's/^v//')"
  if [[ "$current_version" == "$version" ]]; then
    log.debug "[nvm.node.use] Node.js v$version already active"
    return
  fi

  nvm.source
  nvm use "$version"
}


## @function: nvm.node.ensure([version])
##
## @description: Ensures a given or .nvmrc Node.js version is installed and active
nvm.node.ensure() {
  local version="$1"
  nvm.node.install "$version"
  nvm.node.use "$version"
}


## @function: nvm.setup([nvm_version], [node_version])
##
## @description: Ensures correct NVM and Node.js versions are installed and active
##
## @param: nvm_version - optional, fallback to nvm.default_version
## @param: node_version - optional, fallback to .nvmrc
##
## @return: exits 1 on failure
nvm.setup() {
  local nvm_version="${1:-$(nvm.default_version)}"
  local node_version="${2:-$(nvm.node.version.rc)}"

  [[ -z "$node_version" ]] && error.throw "No Node.js version provided and no .nvmrc found"

  nvm.install "$nvm_version"
  nvm.node.ensure "$node_version"
}
