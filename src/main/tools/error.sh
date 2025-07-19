# shellcheck disable=SC1090
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "../core/logger.sh"
import "../tools/file.sh"
import "../tools/string.sh"

__RunningPWD="$(pwd)"

## @function: error.throw(message, [code])
##
## @description: Throw an error and exit unless code is 0 or 1
error.throw() {
  local errorMessage=${1:-"Missing Error Message - ADD IT!"}
  local defaultCode=$?
  local errorCode="${2:-$defaultCode}"
  [[ "${errorCode}" == "0" || "${errorCode}" == "1" ]] && return
  error.__throwImpl "${errorMessage}" "${errorCode}"
}


## @function: error.warn(message, [code])
##
## @description: Throw a warning if code is not 0
error.warn() {
  local errorMessage=${1:-"Missing Warning Message - ADD IT!"}
  local defaultCode=$?
  local errorCode="${2:-$defaultCode}"
  [[ "${errorCode}" == "0" ]] && return
  error.__throwImpl "${errorMessage}" "${errorCode}"
}


## @function: error.__throwImpl(message, code)
##
## @description: Internal implementation to print and trace error
error.__throwImpl() {
  local errorMessage=${1}
  local errorCode=${2}
  local _pwd="${__RunningPWD}/"
  local length
  local alignedLine

  error.__printStacktrace() {
    local sourceFiles=()
    for ((i = 2; i < ${#FUNCNAME[@]}; i++)); do
      sourceFiles+=("$(file.path "${BASH_SOURCE[${i}]}")")
    done

    length=$(string.get_max_length "${sourceFiles[@]}")
    log.error "  Stack:"
    for ((i = 2; i < ${#FUNCNAME[@]}; i++)); do
      local _line="[${BASH_LINENO[$((i - 1))]}]"
      local _file="${sourceFiles[$((i - 2))]}"
      alignedLine=$(printf "%$((6 + length - ${#_file}))s" "${_line}")
      log.error "    ./${_file} ${alignedLine} ${FUNCNAME[${i}]}"
    done
  }

  log.error ""
  log.error "        pwd: ${__RunningPWD}"
  log.error "  error pwd: $(pwd)"
  log.error ""
  log.error "  ERROR: ${errorMessage}"

  error.__printStacktrace

  log.error ""
  log.error "Exiting with Error code: ${errorCode}"
  log.error ""

  exit "${errorCode}"
}
