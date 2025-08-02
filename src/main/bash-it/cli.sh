#!/bin/bash

BASH_IT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${BASH_IT_DIR}/runner.sh"
source "${BASH_IT_DIR}/../core/logger.sh"

print_help() {
  echo -e "\033[1;36mUsage:\033[0m tests-runner.sh [options]"
  echo ""
  echo -e "\033[1;36mOptions:\033[0m"
  echo -e "  \033[1;33m--file\033[0;33m, -f\033[1;35m <pattern>\033[0m     Filter test files by name"
  echo -e "  \033[1;33m--grep\033[0;33m, -g\033[1;35m <pattern>\033[0m     Filter test functions by name"
  echo -e "  \033[1;33m--out\033[0;33m,  -o\033[1;35m <file>\033[0m         Output file for test results"
  echo -e "  \033[1;33m--help\033[0;33m, -h\033[0m               Show this help message"
}

FILE_NAME_FILTER=""
TEST_NAME_FILTER=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --file|-f)
      FILE_NAME_FILTER="$2"
      shift 2
      ;;
    --grep|-g)
      TEST_NAME_FILTER="$2"
      shift 2
      ;;
    --out|-o)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      log.error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

log.debug "Running Bundle: $BUNDLE_NAME v$BUNDLE_VERSION"
tests.run "$FILE_NAME_FILTER" "$TEST_NAME_FILTER" "$OUTPUT_FILE"
