#!/bin/bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/importer.sh"

import "../core/logger.sh"
import "../core/core.sh"
import "../tools/error.sh"
import "../tools/file.sh"

## @function: ssl.generate_cert(key_path, cert_path, days?)
##
## @description: Generate a self-signed SSL certificate using openssl
##
## @param: $1 - Path to output private key file
## @param: $2 - Path to output certificate file
## @param: $3 - Optional number of days validity (default: 365)
##
## @return: null
ssl.generate_cert() {
  local key_path="$1"
  local cert_path="$2"
  local days="${3:-365}"

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
  
  openssl req -x509 -newkey rsa:4096 \
    -keyout "$key_path" \
    -out "$cert_path" \
    -days "$days" \
    -nodes \
    -subj "/CN=localhost" \
    >/dev/null 2>&1

  if [[ ! -f "$key_path" || ! -f "$cert_path" ]]; then
    error.throw "Failed to generate SSL certificate" 1
  fi

  log.info "✅ SSL certificate generated successfully"
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

  local keychain="${HOME}/Library/Keychains/login.keychain-db"
  if [[ ! -f "$keychain" ]]; then
    keychain="${HOME}/Library/Keychains/login.keychain"
  fi

  log.info "Adding certificate to macOS keychain: $cert_path"
  
  # Remove existing certificate if present (ignore errors)
  security delete-certificate -c "localhost" "$keychain" >/dev/null 2>&1 || true

  # Add certificate as trusted root
  if security add-trusted-cert -d -r trustRoot -k "$keychain" "$cert_path" 2>/dev/null; then
    log.info "✅ Certificate trusted successfully in macOS keychain"
  else
    log.warning "Failed to add certificate to keychain automatically"
    log.info "You may need to manually trust the certificate:"
    log.info "  security add-trusted-cert -d -r trustRoot -k '$keychain' '$cert_path'"
    return 1
  fi
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
  local cert_name="localhost-dev.crt"
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

  local keychain="${HOME}/Library/Keychains/login.keychain-db"
  if [[ ! -f "$keychain" ]]; then
    keychain="${HOME}/Library/Keychains/login.keychain"
  fi

  # Extract CN from certificate
  local cert_cn
  cert_cn="$(openssl x509 -in "$cert_path" -noout -subject 2>/dev/null | sed -n 's/.*CN=\([^,]*\).*/\1/p')"
  
  if [[ -z "$cert_cn" ]]; then
    # Fallback: try to find certificate by file hash or use "localhost" as default
    cert_cn="localhost"
    log.debug "Could not extract CN from certificate, using default: $cert_cn"
  fi

  log.info "Removing certificate from macOS keychain: $cert_path (CN: $cert_cn)"
  
  # Remove certificate from keychain (ignore errors if not found)
  if security delete-certificate -c "$cert_cn" "$keychain" >/dev/null 2>&1; then
    log.info "✅ Certificate untrusted successfully from macOS keychain"
  else
    log.debug "Certificate not found in keychain or already removed: $cert_cn"
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
  local cert_name="localhost-dev.crt"
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

