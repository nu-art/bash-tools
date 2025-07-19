DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${DIR}/../core/importer.sh"

import "../core/logger.sh"
import "../tools/error.sh"

## @function: symlink.create(target, link_path)
##
## @description: Create a symbolic link from link_path to the target.
##               Fails if target does not exist or if the symlink already exists.
##
## @return: null
symlink.create() {
  local target="$1"
  local link_path="$2"

  if [[ -z "$target" || -z "$link_path" ]]; then
    error.throw "Missing arguments: target='$target', link_path='$link_path'" 1
  fi

  if [[ ! -e "$target" ]]; then
    error.throw "Target does not exist: $target" 1
  fi

  if [[ -L "$link_path" || -e "$link_path" ]]; then
    log.warning "Link path already exists: $link_path"
    return
  fi

  ln -s "$target" "$link_path"
  log.info "Created symlink: $link_path → $target"
}


## @function: symlink.get_target(link_path)
##
## @description: Returns the target path the symbolic link points to
##
## @return: target path, or null if not a symlink
symlink.get_target() {
  local link_path="$1"

  if [[ ! -L "$link_path" ]]; then
    error.throw "Not a symlink: $link_path" 1
  fi

  readlink "$link_path"
}


## @function: symlink.is_link(path)
##
## @description: Checks if the given path is a symbolic link
##
## @return: true if it's a symlink, null otherwise
symlink.is_link() {
  local path="$1"

  if [[ ! -L "$path" ]]; then
    return 1
  fi
}


## @function: symlink.ensure(target, link_path)
##
## @description: Ensures a symlink points to the correct target.
##               If it exists but points elsewhere, it is replaced.
##
## @return: null
symlink.ensure() {
  local target="$1"
  local link_path="$2"

  if [[ -L "$link_path" ]]; then
    local existing_target
    existing_target="$(readlink "$link_path")"
    if [[ "$existing_target" == "$target" ]]; then
      log.debug "Symlink already correct: $link_path → $target"
      return 0
    fi

    log.info "Replacing existing symlink: $link_path (was → $existing_target)"
    rm "$link_path"
  elif [[ -e "$link_path" ]]; then
    log.error "Cannot replace regular file: $link_path"
    return 1
  fi

  ln -s "$target" "$link_path"
  log.info "Ensured symlink: $link_path → $target"
}


## @function: symlink.remove(link_path)
##
## @description: Removes a symbolic link if it exists and is a link
##
## @return: null
symlink.remove() {
  local link_path="$1"

  if [[ -L "$link_path" ]]; then
    rm "$link_path"
    log.info "Removed symlink: $link_path"
  elif [[ -e "$link_path" ]]; then
    log.warning "Path exists but is not a symlink: $link_path"
  else
    log.debug "Symlink already absent: $link_path"
  fi
}
