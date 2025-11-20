#!/usr/bin/env bash

# Start a gRPC client for any supported language
# This script starts a client that connects to a gRPC server (proxy or backend)

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Default values
DEFAULT_SERVER="localhost:8886"
LANGUAGE=""
SERVER="$DEFAULT_SERVER"
TLS_ENABLED=false

# Display usage information
usage() {
  cat << EOF
Usage: $0 --language <lang> [OPTIONS]

Start a gRPC client for the specified language.
The client connects to a gRPC server (proxy or backend).

Required Arguments:
  --language, -l <lang>    Language implementation to use
                           Supported: java, go, python, nodejs, typescript, rust,
                                     cpp, csharp, kotlin, swift, dart, php

Optional Arguments:
  --server, -s <host:port> Server address to connect to (default: $DEFAULT_SERVER)
  --tls, -t                Enable TLS/secure mode
  --help, -h               Display this help message

Examples:
  # Start Java client connecting to default proxy server (localhost:8886)
  $0 --language java

  # Start Go client connecting to backend server with TLS
  $0 --language go --server localhost:9996 --tls

  # Start Python client
  $0 -l python -s localhost:8886

Environment Variables Set:
  GRPC_SERVER              Server hostname
  GRPC_SERVER_PORT         Server port
  GRPC_HELLO_SECURE        Set to 'Y' when TLS is enabled

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
      --server|-s)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --server"
          usage
        fi
        SERVER="$2"
        shift 2
        ;;
      --tls|-t)
        TLS_ENABLED=true
        shift
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
  
  if [[ ! -d "$cert_dir" ]]; then
    log "ERROR" "TLS certificate directory not found: $cert_dir"
    log "ERROR" "Please run the certificate generation script first"
    log "ERROR" "See docker/tls/generate_grpc_certs.ps1"
    return 1
  fi
  
  local required_files=(
    "$cert_dir/ca.crt"
    "$cert_dir/client_certs/client.crt"
    "$cert_dir/client_certs/client.key"
  )
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      log "ERROR" "Required certificate file not found: $file"
      log "ERROR" "Please run the certificate generation script"
      return 1
    fi
  done
  
  log "INFO" "TLS certificates verified"
  return 0
}

# Main execution
main() {
  local start_time
  local end_time
  local duration
  
  start_time=$(date +%s)
  
  log "INFO" "=========================================="
  log "INFO" "Client Startup Script"
  log "INFO" "=========================================="
  log "INFO" "Script started at: $(date '+%Y-%m-%d %H:%M:%S')"
  
  # Parse arguments
  log "INFO" "Step 1/6: Parsing command line arguments"
  parse_arguments "$@"
  log "INFO" "Arguments parsed successfully"
  
  # Validate language
  log "INFO" "Step 2/6: Validating language support"
  if ! validate_language "$LANGUAGE"; then
    log "ERROR" "Unsupported language: $LANGUAGE"
    log "ERROR" "Supported languages: ${SUPPORTED_LANGUAGES[*]}"
    exit "$EXIT_INVALID_PARAMS"
  fi
  
  log "INFO" "Configuration:"
  log "INFO" "  Language: $LANGUAGE"
  log "INFO" "  Server: $SERVER"
  
  # Parse server into host and port
  log "INFO" "Step 3/6: Parsing server configuration"
  SERVER_HOST="${SERVER%:*}"
  SERVER_PORT="${SERVER##*:}"
  
  # Validate server format
  if [[ -z "$SERVER_HOST" || -z "$SERVER_PORT" ]]; then
    log "ERROR" "Invalid server format: $SERVER (expected host:port)"
    exit "$EXIT_INVALID_PARAMS"
  fi
  
  log "INFO" "Server configuration:"
  log "INFO" "  Host: $SERVER_HOST"
  log "INFO" "  Port: $SERVER_PORT"
  
  # Handle TLS mode
  log "INFO" "Step 4/6: Configuring security mode"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    log "INFO" "TLS mode: ENABLED"
    
    # Get the project root (two levels up from scripts/proxy)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    cd "$PROJECT_ROOT" || exit "$EXIT_ENV_ERROR"
    
    log "INFO" "Verifying TLS certificates..."
    if ! verify_tls_certificates; then
      exit "$EXIT_ENV_ERROR"
    fi
  else
    log "INFO" "TLS mode: DISABLED (insecure connections)"
  fi
  
  # Get language directory
  log "INFO" "Step 5/6: Locating language implementation"
  LANG_DIR=$(get_language_dir "$LANGUAGE")
  if [[ -z "$LANG_DIR" ]]; then
    log "ERROR" "Failed to get directory for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Get the project root if not already set
  if [[ -z "${PROJECT_ROOT:-}" ]]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  fi
  
  FULL_LANG_DIR="$PROJECT_ROOT/$LANG_DIR"
  
  if [[ ! -d "$FULL_LANG_DIR" ]]; then
    log "ERROR" "Language directory not found: $FULL_LANG_DIR"
    exit "$EXIT_ENV_ERROR"
  fi
  
  log "INFO" "Language directory: $FULL_LANG_DIR"
  
  # Navigate to language directory
  cd "$FULL_LANG_DIR" || exit "$EXIT_ENV_ERROR"
  log "INFO" "Changed to language directory"
  
  # Get client command
  log "INFO" "Step 6/6: Preparing and executing client"
  local tls_flag="false"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    tls_flag="true"
  fi
  
  CLIENT_CMD=$(get_client_command "$LANGUAGE" "$SERVER_HOST" "$SERVER_PORT" "$tls_flag")
  if [[ -z "$CLIENT_CMD" ]]; then
    log "ERROR" "Failed to get client command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Environment variables to be set:"
  log "INFO" "  GRPC_SERVER=$SERVER_HOST"
  log "INFO" "  GRPC_SERVER_PORT=$SERVER_PORT"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    log "INFO" "  GRPC_HELLO_SECURE=Y"
  fi
  
  # Log the command being executed
  log "INFO" "Client command: $CLIENT_CMD"
  
  # Execute client command and capture output
  log "INFO" "=========================================="
  log "INFO" "Executing client"
  log "INFO" "=========================================="
  # Note: We use eval here to properly handle the environment variables in the command string
  log "INFO" "Client output:"
  log "INFO" "----------------------------------------"
  
  if eval "$CLIENT_CMD"; then
    CLIENT_EXIT_CODE=0
    log "INFO" "----------------------------------------"
    
    # Calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "INFO" "Client completed successfully"
    log "INFO" "  Exit code: 0"
    log "INFO" "  Duration: ${duration}s"
    log "INFO" "Script completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    exit "$EXIT_SUCCESS"
  else
    CLIENT_EXIT_CODE=$?
    log "ERROR" "----------------------------------------"
    
    # Calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log "ERROR" "Client failed"
    log "ERROR" "  Exit code: $CLIENT_EXIT_CODE"
    log "ERROR" "  Duration: ${duration}s"
    log "ERROR" "Script completed at: $(date '+%Y-%m-%d %H:%M:%S')"
    exit "$EXIT_COMM_ERROR"
  fi
}

# Run main function
main "$@"
