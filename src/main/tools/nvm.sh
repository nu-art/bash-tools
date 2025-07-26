#!/bin/bash

import "../../core/logger.sh"
import "../../tools/error.sh"


## @function: node.nvm.source()
##
## @description: Source the user's NVM script
##
## @return: 0 if sourced, 1 otherwise
node.nvm.source() {
  local nvm_script="$HOME/.nvm/nvm.sh"
  if [[ -s "$nvm_script" ]]; then
    # shellcheck disable=SC1090
    . "$nvm_script"
    return 0
  fi

  return 1
}


## @function: node.ensure_nvm()
##
## @description: Ensures NVM is sourced or fails
##
## @return: 0 on success, exits 1 if not found
node.ensure_nvm() {
  if command -v nvm >/dev/null; then
    return 0
  fi

  if node.nvm.source; then
    return 0
  fi

  error.throw "[node.ensure_nvm] NVM not found. Please run: node.install_nvm"
}


## @function: node.install_nvm()
##
## @description: Installs NVM into ~/.nvm
##
## @return: 0 on success
node.install_nvm() {
  if [[ -d "$HOME/.nvm" ]]; then
    log.info "[node.install_nvm] NVM already installed at: \$HOME/.nvm"
    return 0
  fi

  log.info "[node.install_nvm] Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  node.nvm.source || error.throw "[node.install_nvm] Failed to source NVM after install"
}


## @function: node.uninstall_nvm()
##
## @description: Removes NVM installation and shell config entries
##
## @return: none
node.uninstall_nvm() {
  log.info "[node.uninstall_nvm] Removing NVM from ~/.nvm and shell rc files..."
  rm -rf "$HOME/.nvm"
  sed -i.bak '/NVM_DIR/d;/nvm.sh/d' "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
}


## @function: node.version.read()
##
## @description: Reads version from .nvmrc if exists
##
## @return: version string or empty
node.version.read() {
  if [[ -f .nvmrc ]]; then
    cat .nvmrc
  fi
}


## @function: node.current()
##
## @description: Outputs current active Node.js version
##
## @return: version string or exits 1
node.current() {
  if ! command -v node &>/dev/null; then
    error.throw "[node.current] Node.js not available"
  fi

  node -v
}


## @function: node.install(version)
##
## @description: Installs the specified Node.js version
## @param: version
## @return: 0 on success, exits 1 on failure
node.install() {
  local version="$1"

  [[ -z "$version" ]] && error.throw "[node.install] Missing version param"

  node.ensure_nvm
  nvm install "$version"
}

## @function: node.use(version)
##
## @description: Switches to given Node.js version
## @param: version
## @return: 0 on success, exits 1 on failure
node.use() {
  local version="$1"

  [[ -z "$version" ]] && error.throw "[node.use] Missing version param"

  node.ensure_nvm
  nvm use "$version"
}


## @function: node.ensure([version])
##
## @description: Ensures node is installed + activated for given or .nvmrc version
## @param: version - optional, fallback to .nvmrc
##
## @return: 0 on success, exits 1 on error
node.ensure() {
  node.ensure_nvm

  local version="$1"
  [[ -z "$version" ]] && version=$(node.version.read)

  if [[ -z "$version" ]]; then
    error.throw "[node.ensure] No version specified and .nvmrc not found"
  fi

  local current="$(node.current | sed 's/^v//')"
  if [[ "$current" != "$version" ]]; then
    log.info "[node.ensure] Activating Node.js v$version"
    nvm install "$version"
    nvm use "$version"

  else
    log.info "[node.ensure] Node.js v$version is already active."
  fi
}
