#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "../core/logger.sh"
import "../core/core.sh"
import "../tools/error.sh"
import "../tools/file.sh"

# ============================================================================
# Private Helper Functions
# ============================================================================

## @function: _ssl.get_keychain_path(keychain_type?)
##
## @description: Returns the macOS keychain path based on type
##
## @param: $1 - Optional keychain type: "login" (default) or "system"
##
## @return: Path to the macOS keychain
_ssl.get_keychain_path() {
  local keychain_type="${1:-login}"
  
  if [[ "$keychain_type" == "system" ]]; then
    echo "/Library/Keychains/System.keychain"
  else
    # Default to login keychain (user keychain)
    local login_keychain="${HOME}/Library/Keychains/login.keychain-db"
    if [[ ! -f "$login_keychain" ]]; then
      error.throw "Login keychain not found: $login_keychain" 1
    fi
    echo "$login_keychain"
  fi
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
  local fingerprint
  fingerprint="$(openssl x509 -in "$cert_path" -noout -fingerprint -sha1 2>&1 | sed 's/.*=//' | tr -d ':')"
  if [[ -z "$fingerprint" ]]; then
    error.throw "Failed to extract certificate fingerprint from: $cert_path" 1
  fi
  echo "$fingerprint"
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
  cert_cn="$(openssl x509 -in "$cert_path" -noout -subject 2>&1 | sed -n 's/.*CN=\([^,]*\).*/\1/p')"
  if [[ -z "$cert_cn" ]]; then
    error.throw "Failed to extract certificate CN from: $cert_path" 1
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
  not_after="$(openssl x509 -in "$cert_path" -noout -enddate 2>&1 | cut -d= -f2)"
  
  if [[ -z "$not_after" ]]; then
    error.throw "Failed to read certificate expiration date from: $cert_path. Certificate file may be corrupted or invalid." 1
  fi
  
  # Convert expiration date to timestamp (handle both macOS and Linux date formats)
  local expire_timestamp
  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS date format
    if ! expire_timestamp="$(date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>&1)"; then
      error.throw "Failed to parse certificate expiration date: $not_after (from $cert_path). Certificate file may be corrupted or invalid." 1
    fi
  else
    # Linux date format
    if ! expire_timestamp="$(date -d "$not_after" +%s 2>&1)"; then
      error.throw "Failed to parse certificate expiration date: $not_after (from $cert_path). Certificate file may be corrupted or invalid." 1
    fi
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
  local config_file="${REPO_ROOT}/.config/ssl-certs.conf"
  
  if [[ ! -f "$config_file" ]]; then
    error.throw "SSL certificate config file not found: $config_file" 1
  fi
  
  echo "$config_file"
}

## @function: _ssl.read_config(cert_name)
##
## @description: Reads certificate configuration from .config/ssl-certs.conf (INI-style)
##
## @param: $1 - Certificate name/key to look up in config
##
## @return: Key-value format string: "cn=...|san=...|days=..."
_ssl.read_config() {
  local cert_name="$1"
  local config_file
  config_file="$(_ssl.find_config_file)"
  
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
  
  error.throw "Certificate configuration not found for: $cert_name in $config_file" 1
}

## @function: _ssl.parse_config(config_string)
##
## @description: Parses a configuration string into variables (key-value format)
##
## @param: $1 - Configuration string (key-value: "cn=...|san=...|days=...")
##
## @return: Sets global variables: SSL_CONFIG_CN, SSL_CONFIG_SAN (array), SSL_CONFIG_DAYS
_ssl.parse_config() {
  local config_string="$1"
  SSL_CONFIG_CN=""
  SSL_CONFIG_SAN=()
  SSL_CONFIG_DAYS="365"
  
  if [[ -z "$config_string" ]]; then
    error.throw "Configuration string is empty" 1
  fi
  
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
  
  # Set defaults if not found
  [[ -z "$SSL_CONFIG_CN" ]] && SSL_CONFIG_CN="localhost"
  [[ -z "$SSL_CONFIG_DAYS" ]] && SSL_CONFIG_DAYS="365"
  
  return 0
}

# ============================================================================
# Public Functions
# ============================================================================

## @function: ssl.generate_cert(key_path, cert_path, days?, cn?, domains?)
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
  shift 4
  local domains=("$@")

  if [[ -z "$key_path" || -z "$cert_path" ]]; then
    error.throw "Missing arguments: key_path='$key_path', cert_path='$cert_path'" 1
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    error.throw "openssl is not installed or not in PATH" 1
  fi

  folder.create "$(dirname "$key_path")"
  folder.create "$(dirname "$cert_path")"
  log.info "Generating SSL certificate: $cert_path (valid for $days days)"
  
  # Build SAN string with all domains
  local san_string="DNS:$cn"
  if [[ ${#domains[@]} -gt 0 ]]; then
    for domain in "${domains[@]}"; do
      if [[ -n "$domain" ]]; then
        # Detect if it's an IP address or DNS name
        if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          san_string="${san_string},IP:${domain}"
        else
          san_string="${san_string},DNS:${domain}"
        fi
      fi
    done
  fi
  
  local openssl_output
  openssl_output="$(openssl req -x509 \
          -newkey rsa:4096 \
          -keyout "$key_path" \
          -out "$cert_path" \
          -days "$days" \
          -new \
          -nodes \
          -subj "/CN=$cn" \
          -reqexts SAN \
          -extensions SAN \
          -config <(cat /System/Library/OpenSSL/openssl.cnf \
            <(printf "[SAN]\nsubjectAltName=$san_string")) \
          -sha256 \
          2>&1)"
  local openssl_exit_code=$?

  if [[ $openssl_exit_code -ne 0 ]]; then
    error.throw "Failed to generate SSL certificate: $cert_path. Error: $openssl_output" 1
  fi

  log.info "✅ SSL certificate generated successfully"
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
  shift 4
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
    ssl.untrust_cert "$cert_path"
    
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
  ssl.generate_cert "$key_path" "$cert_path" "$days" "$cn" "${san_entries[@]}"
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
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi
  
  if [[ -f "$cert_path" ]]; then
    return 0
  fi
  
  return 1
}


## @function: ssl.is_cert_in_keychain(cert_path, keychain_type?)
##
## @description: Check if a certificate is already in the macOS keychain
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: 0 if certificate is in keychain, 1 if not (or on non-macOS)
ssl.is_cert_in_keychain() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    return 1  # Certificate file doesn't exist - not in keychain
  fi

  if [[ "$(uname)" != "Darwin" ]]; then
    return 1  # Not macOS - cannot check keychain
  fi

  if ! command -v security >/dev/null 2>&1; then
    error.throw "security command is not available (required for keychain operations)" 1
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path "$keychain_type")"

  if [[ ! -f "$keychain" ]]; then
    error.throw "Keychain not found: $keychain" 1
  fi

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"

  # Check if this specific certificate (by fingerprint) is in keychain
  if security find-certificate -Z "$cert_fingerprint" "$keychain" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}


## @function: ssl.is_cert_trusted(cert_path, keychain_type?)
##
## @description: Check if a certificate is trusted in the macOS keychain
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: 0 if certificate is trusted, 1 if not (or on non-macOS)
ssl.is_cert_trusted() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ ! -f "$cert_path" ]]; then
    error.throw "Certificate file doesn't exist" 1
  fi

  if [[ "$(uname)" != "Darwin" ]]; then
    return 1  # Not macOS - cannot check trust
  fi

  if ! command -v security >/dev/null 2>&1; then
    error.throw "security command is not available (required for trust operations)" 1
  fi

  local keychain
  keychain="$(_ssl.get_keychain_path "$keychain_type")"

  if [[ ! -f "$keychain" ]]; then
    error.throw "Keychain not found: $keychain" 1
  fi

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    error.throw "Failed to extract certificate fingerprint from: $cert_path" 1
  fi

  # Export trust settings to a temporary file
  # trust-settings-export writes to a file, not stdout
  # mktemp creates a temporary file in /tmp (or system temp dir) and returns its path
  # Example: /var/folders/.../tmp.XXXXXX or /tmp/tmp.XXXXXX
  local temp_trust_file
  temp_trust_file="$(mktemp)" || error.throw "Failed to create temporary file for trust settings export" 1
  log.debug "Using temporary file for trust settings export: $temp_trust_file"
  log.debug "Checking certificate signature: $cert_fingerprint"
  
  # -d flag exports admin trust settings, -s flag exports system trust settings
  local export_flag="-d"
  if [[ "$keychain_type" == "system" ]]; then
    export_flag="-s"
  fi

  if ! security trust-settings-export "$export_flag" "$temp_trust_file" 2>&1; then
    rm -f "$temp_trust_file"
    error.throw "Failed to export trust settings - cannot determine trust status" 1
  fi

  # Filter trust settings for fingerprint key or integer 1/3
  local filtered
  filtered="$(grep -E "key>$cert_fingerprint|integer>1|integer>3" "$temp_trust_file")"
  rm -f "$temp_trust_file"

  # Find the first integer (1 or 3) that appears after the fingerprint key
  # 1 = trusted, 3 = not trusted
  local trust_result
  trust_result="$(echo "$filtered" | sed -n "/key>$cert_fingerprint/,/integer>[13]/p" | grep "integer>" | head -1 | sed 's/.*integer>\([13]\)<.*/\1/')"
  
  if [[ "$trust_result" == "1" ]]; then
    return 0
  fi
  
  return 1
}


## @function: _ssl.add_cert_to_keychain_macos(cert_path, keychain_type?)
##
## @description: [PRIVATE] Add a certificate to macOS keychain without trusting it
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null
_ssl.add_cert_to_keychain_macos() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

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
  keychain="$(_ssl.get_keychain_path "$keychain_type")"

  # Check if already in keychain
  if ssl.is_cert_in_keychain "$cert_path" "$keychain_type"; then
    log.debug "Certificate is already in keychain"
    return 0
  fi

  local keychain_name
  if [[ "$keychain_type" == "system" ]]; then
    keychain_name="system keychain"
    log.info "Adding certificate to macOS system keychain: $cert_path"
    log.info "⚠️  This requires administrator privileges (sudo)"
  else
    keychain_name="login keychain"
    log.info "Adding certificate to macOS login keychain: $cert_path"
  fi
  
  # Add certificate to keychain (with sudo if system keychain, without if login)
  if [[ "$keychain_type" == "system" ]]; then
    if ! sudo security add-certificates -k "$keychain" "$cert_path" 2>&1; then
      error.throw "Failed to add certificate to system keychain: $cert_path (requires sudo/admin privileges)" 1
    fi
    log.info "✅ Certificate added to $keychain_name successfully"
  else
    if ! security add-certificates -k "$keychain" "$cert_path" 2>&1; then
      error.throw "Failed to add certificate to login keychain: $cert_path" 1
    fi
    log.info "✅ Certificate added to $keychain_name successfully"
  fi
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


## @function: ssl.add_cert_to_keychain(cert_path, keychain_type?)
##
## @description: Platform-aware function to add certificate to keychain without trusting
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null
ssl.add_cert_to_keychain() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.add_cert_to_keychain_macos "$cert_path" "$keychain_type"
  else
    _ssl.add_cert_to_keychain_linux "$cert_path"
  fi
}


## @function: _ssl.remove_cert_from_keychain_macos(cert_path, keychain_type?)
##
## @description: [PRIVATE] Remove a certificate from macOS keychain (without untrusting - just removes)
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null
_ssl.remove_cert_from_keychain_macos() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

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
  keychain="$(_ssl.get_keychain_path "$keychain_type")"

  local keychain_name
  if [[ "$keychain_type" == "system" ]]; then
    keychain_name="system keychain"
    log.info "Removing certificate from macOS system keychain: $cert_path"
    log.info "⚠️  This requires administrator privileges (sudo)"
  else
    keychain_name="login keychain"
    log.info "Removing certificate from macOS login keychain: $cert_path"
  fi
  
  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"

  if [[ "$keychain_type" == "system" ]]; then
    if ! sudo security delete-certificate -Z "$cert_fingerprint" "$keychain" 2>&1; then
      error.throw "Failed to remove certificate from system keychain: $cert_path (fingerprint: ${cert_fingerprint:0:8}...)" 1
    fi
    log.info "✅ Certificate removed from $keychain_name successfully"
  else
    if ! security delete-certificate -Z "$cert_fingerprint" "$keychain" 2>&1; then
      error.throw "Failed to remove certificate from login keychain: $cert_path (fingerprint: ${cert_fingerprint:0:8}...)" 1
    fi
    log.info "✅ Certificate removed from $keychain_name successfully"
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


## @function: ssl.remove_cert_from_keychain(cert_path, keychain_type?)
##
## @description: Platform-aware function to remove certificate from keychain
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null
ssl.remove_cert_from_keychain() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.remove_cert_from_keychain_macos "$cert_path" "$keychain_type"
  else
    _ssl.remove_cert_from_keychain_linux "$cert_path"
  fi
}


## @function: _ssl.trust_cert_macos(cert_path, keychain_type?)
##
## @description: [PRIVATE] Trust a certificate that is already in the macOS keychain. This function ONLY trusts - it does NOT add certificates. If the certificate is not in the keychain, this function will fail with an error.
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null (throws error if certificate is not in keychain)
##
## @note: Certificate must be added to keychain first using ssl.add_cert_to_keychain()
_ssl.trust_cert_macos() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

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
  keychain="$(_ssl.get_keychain_path "$keychain_type")"

  local keychain_name
  if [[ "$keychain_type" == "system" ]]; then
    keychain_name="system keychain"
    log.info "Trusting certificate in macOS system keychain: $cert_path"
    log.info "⚠️  This requires administrator privileges (sudo)"
  else
    keychain_name="login keychain"
    log.info "Trusting certificate in macOS login keychain: $cert_path"
  fi
  
  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  if [[ -z "$cert_fingerprint" ]]; then
    error.throw "Could not extract certificate fingerprint from: $cert_path" 1
  fi

  # Try to update trust settings for existing certificate
  # The -d flag allows updating trust settings for existing certificates
  if [[ "$keychain_type" == "system" ]]; then
    if ! sudo security add-trusted-cert -d -r trustRoot -k "$keychain" "$cert_path" 2>&1; then
      error.throw "Failed to trust certificate in system keychain: $cert_path" 1
    fi
    log.info "✅ Certificate trusted successfully in $keychain_name"
  else
    if ! security add-trusted-cert -d -r trustRoot -k "$keychain" "$cert_path" 2>&1; then
      error.throw "Failed to trust certificate in login keychain: $cert_path" 1
    fi
    log.info "✅ Certificate trusted successfully in $keychain_name"
  fi
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
    error.throw "CA certificates directory does not exist: $ca_cert_dir. Please create it manually or use a different method." 1
  fi

  # Copy certificate to CA directory (requires sudo)
  if ! sudo cp "$cert_path" "$ca_cert_path" 2>&1; then
    error.throw "Failed to copy certificate to CA directory (requires sudo): $ca_cert_path" 1
  fi
  
  log.info "Certificate copied to $ca_cert_path"
  
  # Update CA certificates
  if ! command -v update-ca-certificates >/dev/null 2>&1; then
    error.throw "update-ca-certificates command not found" 1
  fi
  
  if ! sudo update-ca-certificates 2>&1; then
    error.throw "Failed to update CA certificates" 1
  fi
  
  log.info "✅ Certificate trusted successfully in Linux CA bundle"
}


## @function: ssl.trust_cert(cert_path, keychain_type?)
##
## @description: Platform-aware certificate trust function. This function ONLY trusts - it does NOT add certificates. If the certificate is not in the keychain, this function will fail with an error.
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null (throws error if certificate is not in keychain)
##
## @note: Certificate must be added to keychain first using ssl.add_cert_to_keychain()
ssl.trust_cert() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.trust_cert_macos "$cert_path" "$keychain_type"
  else
    _ssl.trust_cert_linux "$cert_path"
  fi
}


## @function: _ssl.untrust_cert_macos(cert_path, keychain_type?)
##
## @description: [PRIVATE] Untrust a certificate on macOS by removing it from the keychain
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null
_ssl.untrust_cert_macos() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

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
  keychain="$(_ssl.get_keychain_path "$keychain_type")"
  
  local keychain_name
  if [[ "$keychain_type" == "system" ]]; then
    keychain_name="system keychain"
  else
    keychain_name="login keychain"
  fi

  # Get SHA-1 fingerprint to uniquely identify this certificate
  local cert_fingerprint
  cert_fingerprint="$(_ssl.get_cert_fingerprint "$cert_path")"
  
  log.info "Removing certificate from macOS $keychain_name: $cert_path (fingerprint: ${cert_fingerprint:0:8}...)"
  if [[ "$keychain_type" == "system" ]]; then
    log.info "⚠️  This requires administrator privileges (sudo)"
  fi
  
  # Remove certificate from keychain by fingerprint
  if [[ "$keychain_type" == "system" ]]; then
    if ! sudo security delete-certificate -Z "$cert_fingerprint" "$keychain" 2>&1; then
      error.throw "Failed to remove certificate from system keychain: $cert_path (fingerprint: ${cert_fingerprint:0:8}...)" 1
    fi
    log.info "✅ Certificate untrusted successfully from $keychain_name"
  else
    if ! security delete-certificate -Z "$cert_fingerprint" "$keychain" 2>&1; then
      error.throw "Failed to remove certificate from login keychain: $cert_path (fingerprint: ${cert_fingerprint:0:8}...)" 1
    fi
    log.info "✅ Certificate untrusted successfully from $keychain_name"
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
    error.throw "Certificate file does not exist: $cert_path" 1
  fi

  local ca_cert_dir="/usr/local/share/ca-certificates"
  local cert_name
  cert_name="$(_ssl.get_linux_ca_cert_name)"
  local ca_cert_path="${ca_cert_dir}/${cert_name}"

  log.info "Removing certificate from Linux CA bundle: $cert_path"

  if [[ ! -d "$ca_cert_dir" ]]; then
    error.throw "CA certificates directory does not exist: $ca_cert_dir" 1
  fi

  # Remove certificate from CA directory (requires sudo)
  if [[ ! -f "$ca_cert_path" ]]; then
    error.throw "Certificate not found in CA bundle: $ca_cert_path" 1
  fi

  if ! sudo rm -f "$ca_cert_path" 2>&1; then
    error.throw "Failed to remove certificate from CA directory (requires sudo): $ca_cert_path" 1
  fi
  
  log.info "Certificate removed from $ca_cert_path"
  
  # Update CA certificates
  if ! command -v update-ca-certificates >/dev/null 2>&1; then
    error.throw "update-ca-certificates command not found" 1
  fi
  
  if ! sudo update-ca-certificates 2>&1; then
    error.throw "Failed to update CA certificates" 1
  fi
  
  log.info "✅ Certificate untrusted successfully from Linux CA bundle"
}


## @function: ssl.untrust_cert(cert_path, keychain_type?)
##
## @description: Platform-aware certificate untrust function
##
## @param: $1 - Path to certificate file
## @param: $2 - Optional keychain type: "login" (default) or "system"
##
## @return: null
ssl.untrust_cert() {
  local cert_path="$1"
  local keychain_type="${2:-login}"

  if [[ -z "$cert_path" ]]; then
    error.throw "Missing argument: cert_path='$cert_path'" 1
  fi

  if [[ $(isMacOS) ]]; then
    _ssl.untrust_cert_macos "$cert_path" "$keychain_type"
  else
    _ssl.untrust_cert_linux "$cert_path"
  fi
}
