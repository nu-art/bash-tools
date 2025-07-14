
NVM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${NVM_DIR}/../core/logger.sh"

## @function: node.__source_nvm
##
## @description: Source NVM script if available
## @return: 0 if sourced, 1 if not found
node.__source_nvm() {
  local nvm_script="$HOME/.nvm/nvm.sh"
  if [ -s "$nvm_script" ]; then
    # shellcheck disable=SC1090
    . "$nvm_script"
    return 0
  fi
  return 1
}


## @function: node.ensure_nvm
##
## @description: Ensure that NVM is installed and sourced
## @return: none
node.ensure_nvm() {
  if ! command -v nvm &> /dev/null; then
    if ! node.__source_nvm; then
      log.error "[node.ensure_nvm] NVM not found. Please install it using 'node.install_nvm'"
      return 1
    fi
  fi
}


## @function: node.install_nvm
##
## @description: Install NVM (Node Version Manager) from official GitHub
## @return: none
node.install_nvm() {
  if [ -d "$HOME/.nvm" ]; then
    log.info "[node.install_nvm] NVM already installed at $HOME/.nvm"
    return 0
  fi

  log.info "[node.install_nvm] Installing NVM..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  node.__source_nvm
}


## @function: node.uninstall_nvm
##
## @description: Uninstall NVM and all installed node versions
## @return: none
node.uninstall_nvm() {
  log.info "[node.uninstall_nvm] Removing NVM directory..."
  rm -rf "$HOME/.nvm"
  sed -i.bak '/NVM_DIR/d;/nvm.sh/d' "$HOME/.bashrc" "$HOME/.zshrc" 2>/dev/null || true
}


## @function: node.version
##
## @description: Read required Node.js version from .nvmrc
## @return: version string or empty
node.version() {
  if [ -f .nvmrc ]; then
    cat .nvmrc
  fi
}


## @function: node.current
##
## @description: Echo current active Node.js version
## @return: version string
node.current() {
  node -v 2>/dev/null || log.error "[node.current] Node.js not available"
}


## @function: node.install
##
## @description: Install the specified Node.js version using nvm
## @param: version
node.install() {
  local version="$1"
  node.ensure_nvm || return 1
  nvm install "$version"
}


## @function: node.use
##
## @description: Use the specified Node.js version with nvm
## @param: version
node.use() {
  local version="$1"
  node.ensure_nvm || return 1
  nvm use "$version"
}


## @function: node.ensure
##
## @description: Ensure the correct Node.js version is installed and in use
## @param: [version] - optional
## @return: none
node.ensure() {
  node.ensure_nvm || return 1

  local version="$1"
  if [ -z "$version" ]; then
    version=$(node.version)
  fi

  if [ -z "$version" ]; then
    log.error "[node.ensure] No version specified and no .nvmrc found."
    return 1
  fi

  local current
  current=$(node.current)

  if [[ "$current" != "v$version" ]]; then
    log.info "[node.ensure] Switching to Node.js v$version"
    nvm install "$version"
    nvm use "$version"
  else
    log.info "[node.ensure] Node.js v$version is already active."
  fi
}
