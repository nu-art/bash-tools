#!/bin/bash


doc.generate(){

  _print() {
    local format="$1"
    shift

    if [[ -n "$HTML_FILE" ]]; then
      echo "$*" >> "$HTML_FILE"
    elif [[ "$format" ]] && [[ "${USE_COLOR}" ]]; then
      echo -e "\033[${format}m$*\033[0m"
    else
      echo -e "$*"
    fi
  }

  ## @function: doc.generate.file(file_path, grep?)
  ##
  ## @description: Print documentation for a single file
  ##
  ## @param: $1 - path to file
  ## @param: $2 - optional grep filter
  doc.generate.file() {
    local file="$1"
    local filter_func="$2"
    local buffer=()
    local in_block=false
    local printed_header=false

    flush_block() {
      local func=""
      local desc=""
      local params=()
      local returns=""

      for line in "${buffer[@]}"; do
        line="${line##\#\# @}"

        key="${line%%:*}"
        value="${line#*: }"

        case "$key" in
          function)
            func="$value"
            params=()
            returns=""
            desc=""
            ;;
          description) desc="$value" ;;
          param) params+=("$value") ;;
          return) returns="$value" ;;
        esac
      done

      if [[ -n "$func" && ( -z "$filter_func" || "$func" == *"$filter_func"* ) ]]; then
        # skip private functions (starting with _ or group._ prefix)
        if [[ "$func" =~ ^_.* || "$func" =~ ^[a-zA-Z0-9]+\._.* ]]; then
          return
        fi

        local relative_file="${file#./src/main/}"

        if [[ "$printed_header" == false ]]; then
          printed_header=true

          if [[ -n "$HTML_FILE" ]]; then
            _print html "<h2>Documentation for: <code>$relative_file</code></h2><hr>"
          else
            _print 1 "📘 Documentation for: $relative_file"
            _print 2 "--------------------------------------------------"
          fi
        fi

        if [[ -n "$HTML_FILE" ]]; then
          _print html "<h3>$func</h3>"
          [[ -n "$desc" ]] && _print html "<p>$desc</p>"

          if [[ ${#params[@]} -gt 0 ]]; then
            _print html "<strong>Params:</strong><ul>"
            for param in "${params[@]}"; do
              _print html "  <li><code>$param</code></li>"
            done
            _print html "</ul>"
          fi

          [[ -n "$returns" ]] && _print html "<strong>Returns:</strong><p><code>$returns</code></p>"
          _print html "<hr>"
        else
          _print "1;34" "🔧 $func"
          [[ -n "$desc" ]] && echo "    $desc"

          if [[ ${#params[@]} -gt 0 ]]; then
            echo ""
            _print 1 "    Params:"
            for param in "${params[@]}"; do
              echo "      $param"
            done
          fi

          [[ -n "$returns" ]] && {
            echo ""
            _print 1 "    Returns:"
            echo "      $returns"
          }

          echo ""
          _print 2 "-------"
          echo ""
        fi
      fi
    }

    while IFS= read -r line; do
      if [[ "$line" =~ ^## ]]; then
        buffer+=("${line}")
        in_block=true
      elif [[ "$in_block" == true && "$line" =~ ^[a-zA-Z0-9_\.]+\(\) ]]; then
        flush_block
        buffer=()
        in_block=false
      fi
    done < "$file"

    if [[ "$in_block" == true && ${#buffer[@]} -gt 0 ]]; then
      flush_block
    fi
  }

  ## @function: doc.generate.dir(path, grep?)
  ##
  ## @description: Scan directory recursively and document all *.sh files
  ##
  ## @param: $1 - directory path
  ## @param: $2 - optional grep filter
  doc.generate.dir() {
    local dir="$1"
    local pattern="$2"

    [[ -z "$HTML_FILE" ]] && _print 1 "📚 Scanning folder: $dir" && echo "--------------------------------------------------"

    while IFS= read -r file; do
      doc.generate.file "$file" "$pattern"
    done < <(find "$dir" -type f -name "*.sh" | sort)

    [[ -n "$HTML_FILE" ]] && echo "</body></html>" >> "$HTML_FILE"
  }

  USE_COLOR=true
  [[ -t 1 ]] || USE_COLOR=

  local path="$1"
  local grep_pattern="$2"

  if [[ -f "$path" ]]; then
    doc.generate.file "$path" "$grep_pattern"
  elif [[ -d "$path" ]]; then
    doc.generate.dir "$path" "$grep_pattern"
  fi
}