#!/usr/bin/env bash

# Start a TLS-enabled gRPC server for manual testing
# This utility script allows developers to manually start a server with TLS enabled

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions from proxy scripts
# shellcheck source=../proxy/common.sh
source "$SCRIPT_DIR/../proxy/common.sh"

# Default values
DEFAULT_PORT=9996
LANGUAGE=""
PORT="$DEFAULT_PORT"

# Display usage information
usage() {
  cat << EOF
Usage: $0 --language <lang> [OPTIONS]

Start a TLS-enabled gRPC server for manual testing.

Required Arguments:
  --language, -l <lang>    Language implementation to use
                           Supported: java, go, python, nodejs, typescript, rust,
                                     cpp, csharp, kotlin, swift, dart, php

Optional Arguments:
  --port <port>            Server port (default: $DEFAULT_PORT)
  --help, -h               Display this help message

Examples:
  # Start Java TLS server on default port
  $0 --language java

  # Start Go TLS server on custom port
  $0 -l go --port 9997

  # Start Python TLS server
  $0 --language python

Environment:
  The server will be started with TLS enabled (GRPC_HELLO_SECURE=Y).
  Ensure certificates exist in docker/tls/ before starting.

Exit Codes:
  0 - Success (server terminated normally)
  1 - Invalid parameters
  2 - Environment error (missing certificates, directories)
  3 - Process failed to start

EOF
  exit "$EXIT_INVALID_PARAMS"
}

# Parse command line arguments
parse_arguments() {
  if [[ $# -eq 0 ]]; then
    log "ERROR" "No arguments provided"
    usage
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --language|-l)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --language"
          usage
        fi
        LANGUAGE="$2"
        shift 2
        ;;
      --port)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --port"
          usage
        fi
        PORT="$2"
        shift 2
        ;;
      --help|-h)
        usage
        ;;
      *)
        log "ERROR" "Unknown argument: $1"
        usage
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$LANGUAGE" ]]; then
    log "ERROR" "Language parameter is required"
    usage
  fi
}

# Verify TLS certificates exist
verify_tls_certificates() {
  local cert_dir="docker/tls"
  
  log "INFO" "Verifying TLS certificates in $cert_dir..."
  
  if [[ ! -d "$cert_dir" ]]; then
    log "ERROR" "TLS certificate directory not found: $cert_dir"
    log "ERROR" "Please run the certificate generation script first"
    log "ERROR" "See docker/tls/generate_grpc_certs.ps1"
    return 1
  fi
  
  local required_files=(
    "$cert_dir/ca.crt"
    "$cert_dir/server_certs/server.crt"
    "$cert_dir/server_certs/server.key"
    "$cert_dir/client_certs/client.crt"
    "$cert_dir/client_certs/client.key"
  )
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      log "ERROR" "Required certificate file not found: $file"
      log "ERROR" "Please run the certificate generation script"
      log "ERROR" "Command: cd docker/tls && ./generate_grpc_certs.ps1"
      return 1
    fi
  done
  
  log "INFO" "All required TLS certificates verified successfully"
  return 0
}

# Main execution
main() {
  log "INFO" "=========================================="
  log "INFO" "TLS Server Startup Utility"
  log "INFO" "=========================================="
  
  # Parse arguments
  parse_arguments "$@"
  
  # Validate language
  if ! validate_language "$LANGUAGE"; then
    log "ERROR" "Unsupported language: $LANGUAGE"
    log "ERROR" "Supported languages: ${SUPPORTED_LANGUAGES[*]}"
    exit "$EXIT_INVALID_PARAMS"
  fi
  
  log "INFO" "Configuration:"
  log "INFO" "  Language: $LANGUAGE"
  log "INFO" "  Port: $PORT"
  log "INFO" "  TLS Mode: ENABLED"
  
  # Get the project root (two levels up from scripts/tls)
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  cd "$PROJECT_ROOT" || exit "$EXIT_ENV_ERROR"
  
  # Verify TLS certificates
  if ! verify_tls_certificates; then
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Get language directory
  LANG_DIR=$(get_language_dir "$LANGUAGE")
  if [[ -z "$LANG_DIR" ]]; then
    log "ERROR" "Failed to get directory for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  FULL_LANG_DIR="$PROJECT_ROOT/$LANG_DIR"
  
  if [[ ! -d "$FULL_LANG_DIR" ]]; then
    log "ERROR" "Language directory not found: $FULL_LANG_DIR"
    exit "$EXIT_ENV_ERROR"
  fi
  
  log "INFO" "Language directory: $FULL_LANG_DIR"
  
  # Navigate to language directory
  cd "$FULL_LANG_DIR" || exit "$EXIT_ENV_ERROR"
  
  # Get server command with TLS enabled
  local server_cmd
  server_cmd=$(get_server_command "$LANGUAGE" "$PORT" "" "" "true")
  if [[ -z "$server_cmd" ]]; then
    log "ERROR" "Failed to get server command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Server environment variables:"
  log "INFO" "  GRPC_SERVER_PORT=$PORT"
  log "INFO" "  GRPC_HELLO_SECURE=Y"
  
  # Log the command
  log "INFO" "Server command: $server_cmd"
  
  log "INFO" "=========================================="
  log "INFO" "Starting TLS-enabled server..."
  log "INFO" "Press Ctrl+C to stop the server"
  log "INFO" "=========================================="
  
  # Start server (foreground)
  eval "$server_cmd"
  
  log "INFO" "Server terminated"
  exit "$EXIT_SUCCESS"
}

# Run main function
main "$@"
