#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "../core/logger.sh"
import "../core/core.sh"
import "../tools/error.sh"
import "../tools/file.sh"

# ============================================================================
# Private Helper Functions
# ============================================================================

## @function: _ssl.get_keychain_path()
##
## @description: Returns the macOS keychain path (login.keychain-db or login.keychain fallback)
##
## @return: Path to the macOS login keychain
_ssl.get_keychain_path() {
  local keychain="${HOME}/Library/Keychains/login.keychain-db"
  if [[ ! -f "$keychain" ]]; then
    keychain="${HOME}/Library/Keychains/login.keychain"
  fi
  echo "$keychain"
}

## @function: _ssl.get_cert_fingerprint(cert_path)
##
## @description: Extracts SHA-1 fingerprint from certificate
##
## @param: $1 - Path to certificate file
##
## @return: Certificate fingerprint (empty string if extraction fails)
_ssl.get_cert_fingerprint() {
  local cert_path="$1"
  openssl x509 -in "$cert_path" -noout -fingerprint -sha1 2>/dev/null | sed 's/.*=//' | tr -d ':'
}

## @function: _ssl.get_cert_cn(cert_path)
##
## @description: Extracts CN (Common Name) from certificate subject
##
## @param: $1 - Path to certificate file
##
## @return: Certificate CN (defaults to "localhost" if extraction fails)
_ssl.get_cert_cn() {
  local cert_path="$1"
  local cert_cn
  cert_cn="$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | sed -n 's/.*CN=\([^,]*\).*/\1/p')"
  if [[ -z "$cert_cn" ]]; then
    cert_cn="localhost"
  fi
  echo "$cert_cn"
}

## @function: _ssl.get_linux_ca_cert_name()
##
## @description: Returns the Linux CA certificate name
##
## @return: Linux CA certificate name
_ssl.get_linux_ca_cert_name() {
  echo "localhost-dev.crt"
}

## @function: _ssl.find_config_file()
##
## @description: Finds the SSL certificate configuration file in the repo
##
## @return: Path to config file, or empty if not found
_ssl.find_config_file() {
  local REPO_ROOT
  REPO_ROOT="$(folder.repo_root)"
  # Try .conf first (bash-native), then .json for backward compatibility
  local config_file="${REPO_ROOT}/.config/ssl-certs.conf"
  
  if [[ -f "$config_file" ]]; then
    echo "$config_file"
    return 0
  fi
  
  # Fallback to JSON for backward compatibility
  config_file="${REPO_ROOT}/.config/ssl-certs.json"
  if [[ -f "$config_file" ]]; then
    echo "$config_file"
    return 0
  fi
  
  return 1
}

## @function: _ssl.read_config(cert_name)
##
## @description: Reads certificate configuration from .config/ssl-certs.conf (INI-style) or .json
##
## @param: $1 - Certificate name/key to look up in config
##
## @return: Key-value format string: "cn=...|san=...|days=..." or JSON if from .json file
_ssl.read_config() {
  local cert_name="$1"
  local config_file
  config_file="$(_ssl.find_config_file)" || return 1
  
  # Check file extension to determine format
  if [[ "$config_file" == *.conf ]]; then
    # INI-style format - parse with pure bash
    local in_section=false
    local cn="" san_list=() days="365"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Remove comments and trim whitespace
      line="$(echo "$line" | sed 's/#.*$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -z "$line" ]] && continue
      
      # Check for section header [cert_name]
      if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        in_section=false
        if [[ "${BASH_REMATCH[1]}" == "$cert_name" ]]; then
          in_section=true
          cn=""
          san_list=()
          days="365"
        fi
      elif [[ "$in_section" == true ]]; then
        # Parse key=value pairs
        if [[ "$line" =~ ^cn[[:space:]]*=[[:space:]]*(.+)$ ]]; then
          cn="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^san[[:space:]]*=[[:space:]]*(.+)$ ]]; then
          # Split SAN entries by space or comma
          local san_value="${BASH_REMATCH[1]}"
          read -ra SAN_ARRAY <<< "$san_value"
          san_list=("${SAN_ARRAY[@]}")
        elif [[ "$line" =~ ^days[[:space:]]*=[[:space:]]*([0-9]+)$ ]]; then
          days="${BASH_REMATCH[1]}"
        fi
      fi
    done < "$config_file"
    
    # Return config if we found the section and CN
    if [[ "$in_section" == true && -n "$cn" ]]; then
      echo "cn=$cn|san=${san_list[*]}|days=${days}"
      return 0
    fi
    
    return 1
  else
    # JSON format - try using jq if available
    if command -v jq >/dev/null 2>&1; then
      local result
      result="$(jq -c ".[\"$cert_name\"]" "$config_file" 2>/dev/null)"
      # jq returns "null" (as a string) if the key doesn't exist
      if [[ "$result" == "null" || -z "$result" ]]; then
        return 1
      fi
      echo "$result"
      return 0
    fi
    
    # Fallback: simple grep/sed parsing for basic JSON structure
    if [[ -f "$config_file" ]]; then
      local config_block
      config_block="$(sed -n "/\"$cert_name\"[[:space:]]*:[[:space:]]*{/,/^[[:space:]]*}/p" "$config_file" 2>/dev/null)"
      
      if [[ -n "$config_block" ]]; then
        local cn
        cn="$(echo "$config_block" | sed -n 's/.*"cn"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
        
        local san_list=()
        while IFS= read -r san_item; do
          [[ -n "$san_item" ]] && san_list+=("$san_item")
        done < <(echo "$config_block" | sed -n 's/.*"san"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p' | sed 's/"//g' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        local days
        days="$(echo "$config_block" | sed -n 's/.*"days"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)"
        
        if [[ -n "$cn" ]]; then
          echo "cn=$cn|san=${san_list[*]}|days=${days:-365}"
          return 0
        fi
      fi
    fi
  fi
  
  return 1
}

## @function: _ssl.parse_config(config_string)
##
## @description: Parses a configuration string into variables (supports key-value format and JSON)
##
## @param: $1 - Configuration string (key-value: "cn=...|san=...|days=..." or JSON from jq)
##
## @return: Sets global variables: SSL_CONFIG_CN, SSL_CONFIG_SAN (array), SSL_CONFIG_DAYS
_ssl.parse_config() {
  local config_string="$1"
  SSL_CONFIG_CN=""
  SSL_CONFIG_SAN=()
  SSL_CONFIG_DAYS="365"
  
  if [[ -z "$config_string" ]]; then
    return 1
  fi
  
  # Check if it's JSON format (starts with {) - from .json file with jq
  if [[ "$config_string" =~ ^\{ ]]; then
    # JSON format - try using jq if available
    if command -v jq >/dev/null 2>&1; then
      SSL_CONFIG_CN="$(echo "$config_string" | jq -r '.cn // "localhost"')"
      SSL_CONFIG_DAYS="$(echo "$config_string" | jq -r '.days // 365')"
      
      # Extract SAN array
      local san_json
      san_json="$(echo "$config_string" | jq -c '.san // []' 2>/dev/null)"
      if [[ "$san_json" != "[]" && "$san_json" != "null" ]]; then
        while IFS= read -r san_item; do
          [[ -n "$san_item" && "$san_item" != "null" ]] && SSL_CONFIG_SAN+=("$san_item")
        done < <(echo "$san_json" | jq -r '.[]' 2>/dev/null)
      fi
    else
      # JSON format but no jq - use simple regex parsing
      SSL_CONFIG_CN="$(echo "$config_string" | sed -n 's/.*"cn"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
      SSL_CONFIG_DAYS="$(echo "$config_string" | sed -n 's/.*"days"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"
      
      local san_array_content
      san_array_content="$(echo "$config_string" | sed -n 's/.*"san"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p')"
      if [[ -n "$san_array_content" ]]; then
        while IFS= read -r san_item; do
          san_item="$(echo "$san_item" | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//')"
          [[ -n "$san_item" ]] && SSL_CONFIG_SAN+=("$san_item")
        done < <(echo "$san_array_content" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      fi
    fi
  else
    # Key-value format (cn=...|san=...|days=...) - from .conf file
    IFS='|' read -ra PARTS <<< "$config_string"
    for part in "${PARTS[@]}"; do
      if [[ "$part" =~ ^cn=(.+)$ ]]; then
        SSL_CONFIG_CN="${BASH_REMATCH[1]}"
      elif [[ "$part" =~ ^san=(.+)$ ]]; then
        local san_value="${BASH_REMATCH[1]}"
        if [[ -n "$san_value" ]]; then
          # Split SAN entries by space
          read -ra SAN_ARRAY <<< "$san_value"
          SSL_CONFIG_SAN=("${SAN_ARRAY[@]}")
        fi
      elif [[ "$part" =~ ^days=([0-9]+)$ ]]; then
        SSL_CONFIG_DAYS="${BASH_REMATCH[1]}"
      fi
    done
  fi
  
  # Set defaults if not found
  [[ -z "$SSL_CONFIG_CN" ]] && SSL_CONFIG_CN="localhost"
  [[ -z "$SSL_CONFIG_DAYS" ]] && SSL_CONFIG_DAYS="365"
  
  return 0
}

# ============================================================================
# Public Functions
# ============================================================================

## @function: ssl.generate_cert(key_path, cert_path, days?, cn?, san_array?)
##
## @description: Generate a self-signed SSL certificate using openssl
##
## @param: $1 - Path to output private key file
## @param: $2 - Path to output certificate file
## @param: $3 - Optional number of days validity (default: 365)
## @param: $4 - Optional Common Name (CN) for the certificate (default: localhost)
## @param: $5+ - Optional Subject Alternative Names (SAN) - pass multiple DNS names as additional arguments
##
## @return: null
ssl.generate_cert() {
  local key_path="$1"
  local cert_path="$2"
  local days="${3:-365}"
  local cn="${4:-localhost}"
  shift 4 2>/dev/null || shift 3 2>/dev/null || true
  local san_entries=("$@")

  if [[ -z "$key_path" || -z "$cert_path" ]]; then
    error.throw "Missing arguments: key_path='$key_path', cert_path='$cert_path'" 1
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    error.throw "openssl is not installed or not in PATH" 1
  fi

  local key_dir cert_dir
  key_dir="$(dirname "$key_path")"
  cert_dir="$(dirname "$cert_path")"

  [[ ! -d "$key_dir" ]] && mkdir -p "$key_dir"
  [[ ! -d "$cert_dir" ]] && mkdir -p "$cert_dir"

  log.info "Generating SSL certificate: $cert_path (valid for $days days)"
  log.debug "CN: $cn"
  if [[ ${#san_entries[@]} -gt 0 ]]; then
    log.debug "SAN entries: ${san_entries[*]}"
  fi
  
  # If SAN entries are provided, we need to use an openssl config file
  if [[ ${#san_entries[@]} -gt 0 ]]; then
    local temp_config
    temp_config="$(mktemp)"
    
    # Create openssl config with SAN extension
    cat > "$temp_config" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $cn

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
EOF
    
    # Add SAN entries
    local index=1
    for san in "${san_entries[@]}"; do
      echo "DNS.$index = $san" >> "$temp_config"
      index=$((index + 1))
    done
    
    # Generate certificate with config
    openssl req -x509 -newkey rsa:4096 \
      -keyout "$key_path" \
      -out "$cert_path" \
      -days "$days" \
      -nodes \
      -config "$temp_config" \
      -extensions v3_req \
      >/dev/null 2>&1
    
    # Clean up temp config
    rm -f "$temp_config"
  else
    # Simple certificate without SAN
    openssl req -x509 -newkey rsa:4096 \
      -keyout "$key_path" \
      -out "$cert_path" \
      -days "$days" \
      -nodes \
      -subj "/CN=$cn" \
      >/dev/null 2>&1
  fi

  if [[ ! -f "$key_path" || ! -f "$cert_path" ]]; then
    error.throw "Failed to generate SSL certificate" 1
  fi

  log.info "✅ SSL certificate generated successfully"
}


## @function: ssl.generate_cert_with_config(cert_name, key_path?, cert_path?)
##
## @description: Generate SSL certificate using configuration from .config/ssl-certs.json
##
## @param: $1 - Certificate name (key in config file)
## @param: $2 - Optional path to output private key file (default: ~/.local-dev-cert/{cert_name}.key)
## @param: $3 - Optional path to output certificate file (default: ~/.local-dev-cert/{cert_name}.crt)
##
## @return: null
ssl.generate_cert_with_config() {
  local cert_name="$1"
  local key_path="$2"
  local cert_path="$3"
  
  if [[ -z "$cert_name" ]]; then
    error.throw "Missing argument: cert_name" 1
  fi
  
  # Read configuration
  local config_string
  if ! config_string="$(_ssl.read_config "$cert_name")"; then
    error.throw "Certificate configuration not found for: $cert_name. Please create .config/ssl-certs.json" 1
  fi
  
  # Parse configuration
  _ssl.parse_config "$config_string" || error.throw "Failed to parse certificate configuration" 1
  
  # Set default paths if not provided
  local cert_dir="${SSL_CERT_DIR:-${HOME}/.local-dev-cert}"
  if [[ -z "$key_path" ]]; then
    key_path="${cert_dir}/${cert_name}.key"
  fi
  if [[ -z "$cert_path" ]]; then
    cert_path="${cert_dir}/${cert_name}.crt"
  fi
  
  # Generate certificate with config values
  ssl.generate_cert "$key_path" "$cert_path" "$SSL_CONFIG_DAYS" "$SSL_CONFIG_CN" "${SSL_CONFIG_SAN[@]}"
}


## @function: ssl.ensure_cert(key_path, cert_path, days?)
##
## @description: Lazy certificate generation - only generates if files don't exist
##
## @param: $1 - Path to private key file
## @param: $2 - Path to certificate file
## @param: $3 - Optional number of days validity (default: 365)
##
## @return: null
ssl.ensure_cert() {
  local key_path="$1"
  local cert_path="$2"
  local days="${3:-365}"

  if [[ -f "$key_path" && -f "$cert_path" ]]; then
    log.debug "SSL certificate already exists: $cert_path"
    return 0
  fi

  ssl.generate_cert "$key_path" "$cert_path" "$days"
}


## @function: ssl.trust_cert_macos(cert_path)
##
## @description: Trust a certificate on macOS using security command
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.trust_cert_macos() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    error.throw "Certificate file does not exist: $cert_path" 1
  fi

  if ! command -v security >/dev/null 2>&1; then
    error.throw "security command is not available (not on macOS?)" 1
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path)"

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  # Check if certificate exists in keychain
  # Note: We'll still attempt to add-trusted-cert to ensure trust settings are correct,
  # as a certificate can exist in keychain without being trusted
  local cert_exists=false
  
  if [[ -n "$cert_fingerprint" ]]; then
    # Check if certificate exists in keychain
    if security find-certificate -Z "$cert_fingerprint" "$keychain" >/dev/null 2>&1; then
      cert_exists=true
      log.debug "Certificate found in keychain (fingerprint: ${cert_fingerprint:0:8}...)"
      log.debug "Verifying trust settings - certificate may exist but not be trusted"
    fi
  else
    log.warning "Could not extract certificate fingerprint, proceeding with trust attempt"
  fi

  # Check if we're in an interactive terminal
  local is_interactive=false
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    is_interactive=true
  fi
  
  # If certificate exists, we need to verify/update trust settings
  # If it doesn't exist, we need to add it with trust
  if [[ "$cert_exists" == true ]]; then
    log.info "Certificate already exists in keychain - verifying trust settings: $cert_path"
    log.info "⚠️  A security dialog may appear - please approve if prompted"
  else
    log.info "Adding certificate to macOS keychain: $cert_path"
    log.info "⚠️  A security dialog should appear - please approve the certificate trust"
  fi
  
  # Attempt to add/update certificate with trust (add-trusted-cert updates trust even if cert exists)
  # This ensures the certificate is trusted, not just present
  if security add-trusted-cert -r trustRoot -k "$keychain" "$cert_path" 2>/dev/null; then
    if [[ "$cert_exists" == true ]]; then
      log.info "✅ Certificate trust settings verified/updated in macOS keychain"
    else
      log.info "✅ Certificate trusted successfully in macOS keychain"
    fi
    return 0
  fi
  
  # If command failed, check if certificate was actually added (might have been added but trust dialog was dismissed)
  if [[ -n "$cert_fingerprint" ]] && security find-certificate -Z "$cert_fingerprint" "$keychain" >/dev/null 2>&1; then
    log.info "✅ Certificate found in keychain (may need manual trust configuration)"
    log.info "   Open Keychain Access and set the certificate to 'Always Trust'"
    return 0
  fi
  
  # Fallback: Open certificate file to trigger macOS certificate installer GUI
  if [[ "$is_interactive" == true ]] && command -v open >/dev/null 2>&1; then
    log.warning "Failed to add certificate via security command"
    log.info "Opening certificate file in macOS certificate installer..."
    if open "$cert_path" 2>/dev/null; then
      log.info "✅ Certificate file opened - please click 'Add' in the certificate installer dialog"
      log.info "   Then open Keychain Access and set the certificate to 'Always Trust'"
      return 0
    fi
  fi
  
  # Last resort: provide manual instructions
  log.warning "Failed to add certificate to keychain automatically"
  log.info "Please manually trust the certificate:"
  log.info "  1. Double-click the certificate file: $cert_path"
  log.info "  2. Click 'Add' in the certificate installer"
  log.info "  3. Open Keychain Access and find the certificate"
  log.info "  4. Double-click it and set to 'Always Trust'"
  return 1
}


## @function: ssl.trust_cert_linux(cert_path)
##
## @description: Trust a certificate on Linux by updating CA bundle
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.trust_cert_linux() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    error.throw "Certificate file does not exist: $cert_path" 1
  fi

  local ca_cert_dir="/usr/local/share/ca-certificates"
  local cert_name
  cert_name="$(_ssl.get_linux_ca_cert_name)"
  local ca_cert_path="${ca_cert_dir}/${cert_name}"

  log.info "Adding certificate to Linux CA bundle: $cert_path"

  if [[ ! -d "$ca_cert_dir" ]]; then
    log.warning "CA certificates directory does not exist: $ca_cert_dir"
    log.info "You may need to create it manually or use a different method"
    return 1
  fi

  # Copy certificate to CA directory (requires sudo)
  if sudo cp "$cert_path" "$ca_cert_path" 2>/dev/null; then
    log.info "Certificate copied to $ca_cert_path"
    
    # Update CA certificates
    if command -v update-ca-certificates >/dev/null 2>&1; then
      if sudo update-ca-certificates 2>/dev/null; then
        log.info "✅ Certificate trusted successfully in Linux CA bundle"
      else
        log.warning "Failed to update CA certificates"
        log.info "You may need to run manually: sudo update-ca-certificates"
        return 1
      fi
    else
      log.warning "update-ca-certificates command not found"
      log.info "You may need to manually update your CA bundle"
      return 1
    fi
  else
    log.warning "Failed to copy certificate (requires sudo)"
    log.info "You may need to run manually:"
    log.info "  sudo cp '$cert_path' '$ca_cert_path'"
    log.info "  sudo update-ca-certificates"
    return 1
  fi
}


## @function: ssl.trust_cert(cert_path)
##
## @description: Platform-aware certificate trust function
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.trust_cert() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    ssl.trust_cert_macos "$cert_path"
  else
    ssl.trust_cert_linux "$cert_path"
  fi
}


## @function: ssl.untrust_cert_macos(cert_path)
##
## @description: Untrust a certificate on macOS by removing it from the keychain
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.untrust_cert_macos() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    log.warning "Certificate file does not exist: $cert_path (skipping untrust)"
    return 0
  fi

  if ! command -v security >/dev/null 2>&1; then
    log.warning "security command is not available (not on macOS?) - skipping untrust"
    return 0
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path)"

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    log.warning "Could not extract certificate fingerprint, attempting removal by CN"
    # Fallback to CN if fingerprint extraction fails
    local cert_cn
    cert_cn="$(_ssl.get_cert_cn "$cert_path")"
    
    log.info "Removing certificate from macOS keychain: $cert_path (CN: $cert_cn)"
    log.info "⚠️  Please check for a confirmation dialog - you may need to approve the certificate removal in another window"
    
    # Remove certificate from keychain by CN (ignore errors if not found)
    if security delete-certificate -c "$cert_cn" "$keychain" >/dev/null 2>&1; then
      log.info "✅ Certificate untrusted successfully from macOS keychain"
    else
      log.debug "Certificate not found in keychain or already removed: $cert_cn"
    fi
  else
    log.info "Removing certificate from macOS keychain: $cert_path (fingerprint: ${cert_fingerprint:0:8}...)"
    log.info "⚠️  Please check for a confirmation dialog - you may need to approve the certificate removal in another window"
    
    # Remove certificate from keychain by fingerprint (ignore errors if not found)
    if security delete-certificate -Z "$cert_fingerprint" "$keychain" >/dev/null 2>&1; then
      log.info "✅ Certificate untrusted successfully from macOS keychain"
    else
      log.debug "Certificate not found in keychain or already removed (fingerprint: ${cert_fingerprint:0:8}...)"
    fi
  fi
}


## @function: ssl.untrust_cert_linux(cert_path)
##
## @description: Untrust a certificate on Linux by removing it from CA bundle
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.untrust_cert_linux() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    log.warning "Certificate file does not exist: $cert_path (skipping untrust)"
    return 0
  fi

  local ca_cert_dir="/usr/local/share/ca-certificates"
  local cert_name
  cert_name="$(_ssl.get_linux_ca_cert_name)"
  local ca_cert_path="${ca_cert_dir}/${cert_name}"

  log.info "Removing certificate from Linux CA bundle: $cert_path"

  if [[ ! -d "$ca_cert_dir" ]]; then
    log.debug "CA certificates directory does not exist: $ca_cert_dir (certificate may not be trusted)"
    return 0
  fi

  # Remove certificate from CA directory (requires sudo)
  if [[ -f "$ca_cert_path" ]]; then
    if sudo rm -f "$ca_cert_path" 2>/dev/null; then
      log.info "Certificate removed from $ca_cert_path"
      
      # Update CA certificates
      if command -v update-ca-certificates >/dev/null 2>&1; then
        if sudo update-ca-certificates 2>/dev/null; then
          log.info "✅ Certificate untrusted successfully from Linux CA bundle"
        else
          log.warning "Failed to update CA certificates after removal"
          log.info "You may need to run manually: sudo update-ca-certificates"
        fi
      else
        log.warning "update-ca-certificates command not found"
        log.info "You may need to manually update your CA bundle"
      fi
    else
      log.warning "Failed to remove certificate from CA directory (requires sudo)"
      log.info "You may need to run manually: sudo rm '$ca_cert_path'"
    fi
  else
    log.debug "Certificate not found in CA bundle: $ca_cert_path (may not be trusted)"
  fi
}


## @function: ssl.untrust_cert(cert_path)
##
## @description: Platform-aware certificate untrust function
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.untrust_cert() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    ssl.untrust_cert_macos "$cert_path"
  else
    ssl.untrust_cert_linux "$cert_path"
  fi
}

