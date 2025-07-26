#!/bin/bash
set -e

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bundler.sh"

print_help() {
  echo -e "\033[1;36mUsage:\033[0m bundle.sh [options]"
  echo ""
  echo -e "\033[1;36mOptions:\033[0m"
  echo -e "  \033[1;33m--source\033[0;33m, -s\033[1;35m <folder>\033[0m    Source folder to search for bundle files"
  echo -e "  \033[1;33m--dist\033[0;33m,   -d\033[1;35m <folder>\033[0m    Target output directory for bundled files"
  echo -e "  \033[1;33m--help\033[0;33m,   -h\033[0m              Show this help message"
}

BUNDLER_SOURCE_ROOT=""
BUNDLER_DIST_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --source|-s)
      BUNDLER_SOURCE_ROOT="$2"
      shift 2
      ;;
    --dist|-d)
      BUNDLER_DIST_DIR="$2"
      shift 2
      ;;
    *)
      echo -e "❌ \033[0;31mUnknown parameter:\033[0m $1" >&2
      exit 1
      ;;
  esac
done

bundler.run "$BUNDLER_SOURCE_ROOT" "$BUNDLER_DIST_DIR"


