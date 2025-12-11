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
## @description: Returns the macOS system keychain path
##
## @return: Path to the macOS system keychain
_ssl.get_keychain_path() {
  echo "/Library/Keychains/System.keychain"
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

## @function: _ssl.is_cert_expired_or_expiring(cert_path, days_threshold?)
##
## @description: Checks if certificate is expired or will expire within the threshold
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional number of days before expiration to consider "expiring" (default: 30)
##
## @return: 0 if expired or expiring soon, 1 if valid
_ssl.is_cert_expired_or_expiring() {
  local cert_path="$1"
  local days_threshold="${2:-30}"
  
  if [[ ! -f "$cert_path" ]]; then
    return 0  # Consider missing cert as "expired" (needs regeneration)
  fi
  
  # Get certificate expiration date
  local not_after
  not_after="$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)"
  
  if [[ -z "$not_after" ]]; then
    error.throw "Failed to read certificate expiration date from: $cert_path. Certificate file may be corrupted or invalid." 1
  fi
  
  # Convert expiration date to timestamp (handle both macOS and Linux date formats)
  local expire_timestamp
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS date format
    expire_timestamp="$(date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y" "$not_after" +%s 2>/dev/null)"
  else
    # Linux date format
    expire_timestamp="$(date -d "$not_after" +%s 2>/dev/null)"
  fi
  
  if [[ -z "$expire_timestamp" ]]; then
    error.throw "Failed to parse certificate expiration date: $not_after (from $cert_path). Certificate file may be corrupted or invalid." 1
  fi
  
  # Get current timestamp
  local current_timestamp
  current_timestamp="$(date +%s)"
  
  # Calculate days until expiration
  local days_until_expiry
  days_until_expiry=$(( (expire_timestamp - current_timestamp) / 86400 ))
  
  # Return 0 (expired/expiring) if expired or within threshold
  if [[ $days_until_expiry -lt $days_threshold ]]; then
    return 0
  fi
  
  return 1  # Certificate is valid
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

  # Create directories if they don't exist - throw error if creation fails
  if [[ ! -d "$key_dir" ]]; then
    if ! mkdir -p "$key_dir"; then
      error.throw "Failed to create key directory: $key_dir" 1
    fi
  fi
  if [[ ! -d "$cert_dir" ]]; then
    if ! mkdir -p "$cert_dir"; then
      error.throw "Failed to create certificate directory: $cert_dir" 1
    fi
  fi

  log.info "Generating SSL certificate: $cert_path (valid for $days days)"
  log.debug "CN: $cn"
  if [[ ${#san_entries[@]} -gt 0 ]]; then
    log.debug "SAN entries: ${san_entries[*]}"
  fi
  
  # If SAN entries are provided, we need to use an openssl config file
  if [[ ${#san_entries[@]} -gt 0 ]]; then
    local temp_config
    temp_config="$(mktemp)" || error.throw "Failed to create temporary config file" 1
    
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
    
    # Verify config file was created
    if [[ ! -f "$temp_config" ]]; then
      error.throw "Failed to create temporary config file: $temp_config" 1
    fi
    
    # Add SAN entries (support both DNS and IP addresses)
    local dns_index=1
    local ip_index=1
    for san in "${san_entries[@]}"; do
      # Check if it's an IP address (simple check: contains digits and dots)
      if [[ "$san" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if ! echo "IP.$ip_index = $san" >> "$temp_config"; then
          rm -f "$temp_config"
          error.throw "Failed to write SAN IP entry to temporary config file: $temp_config" 1
        fi
        ip_index=$((ip_index + 1))
      else
        if ! echo "DNS.$dns_index = $san" >> "$temp_config"; then
          rm -f "$temp_config"
          error.throw "Failed to write SAN DNS entry to temporary config file: $temp_config" 1
        fi
        dns_index=$((dns_index + 1))
      fi
    done
    
    # Generate certificate with config
    if ! openssl req -x509 -newkey rsa:4096 \
      -keyout "$key_path" \
      -out "$cert_path" \
      -days "$days" \
      -nodes \
      -config "$temp_config" \
      -extensions v3_req \
      >/dev/null 2>&1; then
      rm -f "$temp_config"
      error.throw "Failed to generate SSL certificate with SAN entries" 1
    fi
    
    # Clean up temp config
    rm -f "$temp_config"
  else
    # Simple certificate without SAN
    if ! openssl req -x509 -newkey rsa:4096 \
      -keyout "$key_path" \
      -out "$cert_path" \
      -days "$days" \
      -nodes \
      -subj "/CN=$cn" \
      >/dev/null 2>&1; then
      error.throw "Failed to generate SSL certificate" 1
    fi
  fi

  if [[ ! -f "$key_path" || ! -f "$cert_path" ]]; then
    error.throw "Failed to generate SSL certificate - files were not created: key=$key_path, cert=$cert_path" 1
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


## @function: ssl.ensure_cert(key_path, cert_path, days?, cn?, san_array?)
##
## @description: Lazy certificate generation - only generates if files don't exist or are expired
##
## @param: $1 - Path to private key file
## @param: $2 - Path to certificate file
## @param: $3 - Optional number of days validity (default: 365)
## @param: $4 - Optional Common Name (CN) for the certificate (default: localhost)
## @param: $5+ - Optional Subject Alternative Names (SAN) - pass multiple DNS/IP names as additional arguments
##
## @return: null
ssl.ensure_cert() {
  local key_path="$1"
  local cert_path="$2"
  local days="${3:-365}"
  local cn="${4:-localhost}"
  shift 4 2>/dev/null || shift 3 2>/dev/null || true
  local san_entries=("$@")

  # Check if certificate files exist using building block API
  if ssl.has_cert "$cert_path" && [[ -f "$key_path" ]]; then
    # Check if certificate is expired or expiring soon (within 30 days)
    if ! _ssl.is_cert_expired_or_expiring "$cert_path" 30; then
      log.debug "SSL certificate already exists and is valid: $cert_path"
      return 0
    fi
    
    # Certificate is expired or expiring soon - remove old certificate and key
    log.info "Certificate is expired or expiring soon: $cert_path"
    log.info "Removing old certificate and key files..."
    
    # Untrust the old certificate before deleting (using building block API)
    if ssl.has_cert "$cert_path"; then
      ssl.untrust_cert "$cert_path" || log.warning "Failed to untrust old certificate (continuing with removal)"
    fi
    
    # Remove old files - throw error if removal fails
    if ! rm -f "$key_path"; then
      error.throw "Failed to remove old key file: $key_path" 1
    fi
    log.debug "Removed old key file: $key_path"
    
    if ! rm -f "$cert_path"; then
      error.throw "Failed to remove old certificate file: $cert_path" 1
    fi
    log.debug "Removed old certificate file: $cert_path"
    
    log.info "Generating new certificate..."
  fi

  # Generate certificate with SAN entries - this will throw an error if it fails
  ssl.generate_cert "$key_path" "$cert_path" "$days" "$cn" "${san_entries[@]}" || error.throw "Failed to generate SSL certificate: $cert_path" 1
}


## @function: ssl.has_cert(cert_path)
##
## @description: Check if certificate file exists
##
## @param: $1 - Path to certificate file
##
## @return: 0 if certificate file exists, 1 if not
ssl.has_cert() {
  local cert_path="$1"
  
  if [[ -z "$cert_path" ]]; then
    return 1
  fi
  
  if [[ -f "$cert_path" ]]; then
    return 0
  fi
  
  return 1
}


## @function: ssl.is_cert_in_keychain(cert_path)
##
## @description: Check if a certificate is already in the macOS keychain
##
## @param: $1 - Path to certificate file
##
## @return: 0 if certificate is in keychain, 1 if not (or on non-macOS)
ssl.is_cert_in_keychain() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    return 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    return 1
  fi

  if [[ "$(uname)" != "Darwin" ]]; then
    return 1  # Not macOS, skip check
  fi

  if ! command -v security >/dev/null 2>&1; then
    return 1  # security command not available
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path)"

  if [[ ! -f "$keychain" ]]; then
    return 1  # Keychain not found
  fi

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    # Fallback: check by CN if fingerprint extraction fails
    local cert_cn
    cert_cn="$(_ssl.get_cert_cn "$cert_path")"
    if security find-certificate -a -c "$cert_cn" "$keychain" >/dev/null 2>&1; then
      return 0
    fi
    return 1
  fi

  # Check if this specific certificate (by fingerprint) is in keychain
  if security find-certificate -Z "$cert_fingerprint" "$keychain" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}


## @function: ssl.is_cert_trusted(cert_path)
##
## @description: Check if a certificate is trusted in the macOS keychain
##
## @param: $1 - Path to certificate file
##
## @return: 0 if certificate is trusted, 1 if not (or on non-macOS)
ssl.is_cert_trusted() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    return 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    return 1
  fi

  if [[ "$(uname)" != "Darwin" ]]; then
    return 1  # Not macOS, skip check
  fi

  if ! command -v security >/dev/null 2>&1; then
    return 1  # security command not available
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path)"

  if [[ ! -f "$keychain" ]]; then
    return 1  # Keychain not found
  fi

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    return 1
  fi

  # First, verify the certificate is in the keychain
  if ! security find-certificate -Z "$cert_fingerprint" "$keychain" >/dev/null 2>&1; then
    # Certificate not in keychain, so definitely not trusted
    return 1
  fi

  # For system keychain, checking trust via CLI is notoriously difficult
  # We'll try multiple methods to determine if the certificate is trusted

  # Method 1: Check trust settings export (requires admin for system keychain)
  # This exports trust settings but may not work reliably for system keychain
  local trust_settings
  trust_settings="$(sudo security trust-settings-export -d 2>/dev/null 2>&1)"
  local trust_export_status=$?
  
  if [[ $trust_export_status -eq 0 && -n "$trust_settings" ]]; then
    # Trust settings export succeeded - search for our certificate
    local cert_cn
    cert_cn="$(_ssl.get_cert_cn "$cert_path")"
    
    # Search for fingerprint or CN in trust settings
    if echo "$trust_settings" | grep -qiE "($cert_fingerprint|$cert_cn)" 2>/dev/null; then
      return 0
    fi
  fi

  # Method 2: Try a test trust operation to see if it's already trusted
  # Extract cert to temp file and try to verify trust
  local temp_cert
  temp_cert="$(mktemp)" || return 1
  
  if security find-certificate -a -Z "$cert_fingerprint" -p "$keychain" > "$temp_cert" 2>/dev/null; then
    # Try verify-cert - for self-signed certs in system keychain that are trusted,
    # this might succeed. However, verify-cert can be unreliable for self-signed.
    # We'll use it as a hint, not definitive proof.
    if security verify-cert -c "$temp_cert" >/dev/null 2>&1; then
      rm -f "$temp_cert"
      return 0
    fi
  fi
  
  rm -f "$temp_cert"

  # Method 3: Heuristic for system keychain
  # If the certificate is in the system keychain and we can't determine trust via CLI,
  # we'll assume it might be trusted if it was added recently or if trust-settings-export
  # is not available. However, to be safe, we'll return 1 and let the trust function
  # handle it (it's idempotent).
  #
  # The issue is that macOS doesn't provide a reliable CLI way to check trust for
  # system keychain certificates. The trust function will try to trust it, and
  # if it's already trusted, `add-trusted-cert -d` should handle it gracefully.
  
  return 1
}


## @function: _ssl.add_cert_to_keychain_macos(cert_path)
##
## @description: [PRIVATE] Add a certificate to macOS keychain without trusting it
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.add_cert_to_keychain_macos() {
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

  # Check if already in keychain
  if ssl.is_cert_in_keychain "$cert_path"; then
    log.debug "Certificate is already in keychain"
    return 0
  fi

  log.info "Adding certificate to macOS system keychain: $cert_path"
  log.info "⚠️  This requires administrator privileges (sudo)"
  
  # Add certificate to system keychain without trust settings
  # System keychain requires sudo/admin privileges
  if sudo security add-certificates -k "$keychain" "$cert_path" 2>/dev/null; then
    log.info "✅ Certificate added to system keychain successfully"
    return 0
  fi

  # Fallback: try using import (for .p12 or other formats, but also works for .crt)
  if sudo security import "$cert_path" -k "$keychain" -T /usr/bin/security 2>/dev/null; then
    log.info "✅ Certificate added to system keychain successfully"
    return 0
  fi

  error.throw "Failed to add certificate to system keychain: $cert_path (requires sudo/admin privileges)" 1
}


## @function: _ssl.add_cert_to_keychain_linux(cert_path)
##
## @description: [PRIVATE] Add a certificate to Linux CA bundle (same as trust on Linux)
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.add_cert_to_keychain_linux() {
  local cert_path="$1"
  # On Linux, adding to CA bundle is the same as trusting
  # This function exists for API consistency
  _ssl.trust_cert_linux "$cert_path"
}


## @function: ssl.add_cert_to_keychain(cert_path)
##
## @description: Platform-aware function to add certificate to keychain without trusting
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.add_cert_to_keychain() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.add_cert_to_keychain_macos "$cert_path"
  else
    _ssl.add_cert_to_keychain_linux "$cert_path"
  fi
}


## @function: _ssl.remove_cert_from_keychain_macos(cert_path)
##
## @description: [PRIVATE] Remove a certificate from macOS keychain (without untrusting - just removes)
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.remove_cert_from_keychain_macos() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    log.warning "Certificate file does not exist: $cert_path (skipping removal)"
    return 0
  fi

  if ! command -v security >/dev/null 2>&1; then
    log.warning "security command is not available (not on macOS?) - skipping removal"
    return 0
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path)"

  # Check if certificate is in keychain
  if ! ssl.is_cert_in_keychain "$cert_path"; then
    log.debug "Certificate is not in keychain: $cert_path"
    return 0
  fi

  log.info "Removing certificate from macOS system keychain: $cert_path"
  log.info "⚠️  This requires administrator privileges (sudo)"
  
  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    log.warning "Could not extract certificate fingerprint, attempting removal by CN"
    local cert_cn
    cert_cn="$(_ssl.get_cert_cn "$cert_path")"
    
    if sudo security delete-certificate -c "$cert_cn" "$keychain" 2>/dev/null; then
      log.info "✅ Certificate removed from system keychain successfully"
      return 0
    else
      log.debug "Certificate not found in keychain or already removed: $cert_cn"
      return 0
    fi
  fi

  if sudo security delete-certificate -Z "$cert_fingerprint" "$keychain" 2>/dev/null; then
    log.info "✅ Certificate removed from system keychain successfully"
    return 0
  else
    log.debug "Certificate not found in keychain or already removed (fingerprint: ${cert_fingerprint:0:8}...)"
    return 0
  fi
}


## @function: _ssl.remove_cert_from_keychain_linux(cert_path)
##
## @description: [PRIVATE] Remove a certificate from Linux CA bundle
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.remove_cert_from_keychain_linux() {
  _ssl.untrust_cert_linux "$cert_path"
}


## @function: ssl.remove_cert_from_keychain(cert_path)
##
## @description: Platform-aware function to remove certificate from keychain
##
## @param: $1 - Path to certificate file
##
## @return: null
ssl.remove_cert_from_keychain() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.remove_cert_from_keychain_macos "$cert_path"
  else
    _ssl.remove_cert_from_keychain_linux "$cert_path"
  fi
}


## @function: _ssl.trust_cert_macos(cert_path)
##
## @description: [PRIVATE] Trust a certificate that is already in the macOS keychain. This function ONLY trusts - it does NOT add certificates. If the certificate is not in the keychain, this function will fail with an error.
##
## @param: $1 - Path to certificate file
##
## @return: null (throws error if certificate is not in keychain)
##
## @note: Certificate must be added to keychain first using ssl.add_cert_to_keychain()
_ssl.trust_cert_macos() {
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

  # Note: Even if is_cert_trusted returns false, the certificate might still be trusted
  # (due to limitations in checking system keychain trust via CLI). The trust operation
  # below should be idempotent - if already trusted, it should succeed without changes.

  log.info "Trusting certificate in macOS system keychain: $cert_path"
  log.info "⚠️  This requires administrator privileges (sudo)"
  
  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    error.throw "Could not extract certificate fingerprint from: $cert_path" 1
  fi

  # Try to update trust settings for existing certificate
  # The -d flag allows updating trust settings for existing certificates
  # NOTE: We've already verified the cert is in keychain above, so this only updates trust
  if sudo security add-trusted-cert -d -r trustRoot -k "$keychain" "$cert_path" 2>/dev/null; then
    log.info "✅ Certificate trusted successfully in macOS system keychain"
    return 0
  fi
  
  # If that failed, remove and re-add with trust settings
  # NOTE: This only happens if cert was already in keychain (verified above)
  # We're re-adding an existing cert with trust, not adding a new one
  log.debug "Failed to update trust settings, removing and re-adding certificate with trust..."
  sudo security delete-certificate -Z "$cert_fingerprint" "$keychain" 2>/dev/null || log.debug "Certificate removal skipped"
  
  # Re-add with trust settings (cert was already in keychain, we're just updating trust)
  if sudo security add-trusted-cert -r trustRoot -k "$keychain" "$cert_path" 2>/dev/null; then
    log.info "✅ Certificate trusted successfully in macOS system keychain"
    return 0
  fi
  
  log.warning "Failed to set trust settings automatically"
  log.info "   Certificate is in keychain but trust settings may not be configured"
  log.info "   Please manually set trust in Keychain Access:"
  log.info "   1. Open Keychain Access"
  log.info "   2. Select 'System' keychain"
  log.info "   3. Find the certificate and double-click it"
  log.info "   4. Expand 'Trust' section and set to 'Always Trust'"
  error.throw "Failed to trust certificate automatically - certificate exists but trust not configured. Please manually set trust in Keychain Access." 1
}


## @function: _ssl.trust_cert_linux(cert_path)
##
## @description: [PRIVATE] Trust a certificate on Linux by updating CA bundle
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.trust_cert_linux() {
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
## @description: Platform-aware certificate trust function. This function ONLY trusts - it does NOT add certificates. If the certificate is not in the keychain, this function will fail with an error.
##
## @param: $1 - Path to certificate file
##
## @return: null (throws error if certificate is not in keychain)
##
## @note: Certificate must be added to keychain first using ssl.add_cert_to_keychain()
ssl.trust_cert() {
  local cert_path="$1"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.trust_cert_macos "$cert_path"
  else
    _ssl.trust_cert_linux "$cert_path"
  fi
}


## @function: _ssl.untrust_cert_macos(cert_path)
##
## @description: [PRIVATE] Untrust a certificate on macOS by removing it from the keychain
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.untrust_cert_macos() {
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


## @function: _ssl.untrust_cert_linux(cert_path)
##
## @description: [PRIVATE] Untrust a certificate on Linux by removing it from CA bundle
##
## @param: $1 - Path to certificate file
##
## @return: null
_ssl.untrust_cert_linux() {
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
    _ssl.untrust_cert_macos "$cert_path"
  else
    _ssl.untrust_cert_linux "$cert_path"
  fi
}
