#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/generator.sh"

print_help() {
  echo -e "\033[1;36mUsage:\033[0m doc.generate --path\033[1;35m <file|dir>\033[0m [options]"
  echo ""
  echo -e "\033[1;36mOptions:\033[0m"
  echo -e "  \033[1;33m--path\033[0;33m, -p\033[1;35m <file|dir>\033[0m   Source path (file or directory)"
  echo -e "  \033[1;33m--grep\033[0;33m, -g\033[1;35m <pattern>\033[0m     Filter function names matching pattern"
  echo -e "  \033[1;33m--html\033[0;33m, -o\033[1;35m <file>\033[0m         Output documentation as HTML file"
  echo -e "  \033[1;33m--help\033[0;33m, -h\033[0m                Show this help message"
}

## @function: doc.generate(...args)
##
## @description: CLI entry point for printing docs. Supports --path file|folder, --grep, and --html.
##
## @param: --path <file|folder> Optional path to a bash file or folder. Defaults to current script.
## @param: --grep <pattern> Optional pattern to match specific function names.
## @param: --html <file> Optional path to output HTML file.
path=""
grep_pattern=""
HTML_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    --path|-p)
      path="$2"
      shift 2
      ;;
    --grep|-g)
      grep_pattern="$2"
      shift 2
      ;;
    --html|-o)
      HTML_FILE="$2"
      shift 2
      [[ -f "$HTML_FILE" ]] && rm "$HTML_FILE"
      echo "<html><body style='font-family: sans-serif;'>" >> "$HTML_FILE"
      ;;
    *)
      echo -e "❌ \033[0;31mUnknown parameter:\033[0m $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$path" ]]; then
  path="${BASH_SOURCE[1]}"
fi

if [[ ! -e "$path" ]]; then
  echo -e "❌ \033[0;31mInvalid --path:\033[0m $path" >&2
  exit 1
fi

generate_docs "$path" "$grep_pattern"

