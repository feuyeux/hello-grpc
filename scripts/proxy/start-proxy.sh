#!/usr/bin/env bash

# Start a proxy gRPC server for any supported language
# This script starts a proxy server that forwards requests to a backend server

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Default values
DEFAULT_PORT=8886
DEFAULT_BACKEND="localhost:9996"
LANGUAGE=""
PORT="$DEFAULT_PORT"
BACKEND="$DEFAULT_BACKEND"
TLS_ENABLED=false

# Display usage information
usage() {
  cat << EOF
Usage: $0 --language <lang> [OPTIONS]

Start a proxy gRPC server for the specified language.
The proxy server forwards requests to a backend server.

Required Arguments:
  --language, -l <lang>    Language implementation to use
                           Supported: java, go, python, nodejs, typescript, rust,
                                     cpp, csharp, kotlin, swift, dart, php

Optional Arguments:
  --port, -p <port>        Port for proxy server (default: $DEFAULT_PORT)
  --backend, -b <host:port> Backend server address (default: $DEFAULT_BACKEND)
  --tls, -t                Enable TLS/secure mode
  --help, -h               Display this help message

Examples:
  # Start Java proxy server on default port 8886, forwarding to localhost:9996
  $0 --language java

  # Start Go proxy server on custom port with TLS
  $0 --language go --port 8888 --backend localhost:9000 --tls

  # Start Python proxy server
  $0 -l python -p 8886 -b localhost:9996

Environment Variables Set:
  GRPC_SERVER_PORT         Port the proxy server listens on
  GRPC_HELLO_BACKEND       Backend server hostname
  GRPC_HELLO_BACKEND_PORT  Backend server port
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
      --port|-p)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --port"
          usage
        fi
        PORT="$2"
        shift 2
        ;;
      --backend|-b)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --backend"
          usage
        fi
        BACKEND="$2"
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
    "$cert_dir/server_certs/server.crt"
    "$cert_dir/server_certs/server.key"
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
  log "INFO" "=========================================="
  log "INFO" "Proxy Server Startup Script"
  log "INFO" "=========================================="
  log "INFO" "Script started at: $(date '+%Y-%m-%d %H:%M:%S')"
  
  # Parse arguments
  log "INFO" "Step 1/7: Parsing command line arguments"
  parse_arguments "$@"
  log "INFO" "Arguments parsed successfully"
  
  # Validate language
  log "INFO" "Step 2/7: Validating language support"
  if ! validate_language "$LANGUAGE"; then
    log "ERROR" "Unsupported language: $LANGUAGE"
    log "ERROR" "Supported languages: ${SUPPORTED_LANGUAGES[*]}"
    exit "$EXIT_INVALID_PARAMS"
  fi
  
  log "INFO" "Configuration:"
  log "INFO" "  Language: $LANGUAGE"
  log "INFO" "  Proxy port: $PORT"
  log "INFO" "  Backend: $BACKEND"
  
  # Parse backend into host and port
  log "INFO" "Step 3/7: Parsing backend configuration"
  BACKEND_HOST="${BACKEND%:*}"
  BACKEND_PORT="${BACKEND##*:}"
  
  # Validate backend format
  if [[ -z "$BACKEND_HOST" || -z "$BACKEND_PORT" ]]; then
    log "ERROR" "Invalid backend format: $BACKEND (expected host:port)"
    exit "$EXIT_INVALID_PARAMS"
  fi
  
  log "INFO" "Backend configuration:"
  log "INFO" "  Host: $BACKEND_HOST"
  log "INFO" "  Port: $BACKEND_PORT"
  
  # Handle TLS mode
  log "INFO" "Step 4/7: Configuring security mode"
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
  log "INFO" "Step 5/7: Locating language implementation"
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
  
  # Get server command (proxy mode with backend configuration)
  log "INFO" "Step 6/7: Preparing proxy server command"
  local tls_flag="false"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    tls_flag="true"
  fi
  
  SERVER_CMD=$(get_server_command "$LANGUAGE" "$PORT" "$BACKEND_HOST" "$BACKEND_PORT" "$tls_flag")
  if [[ -z "$SERVER_CMD" ]]; then
    log "ERROR" "Failed to get server command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Environment variables to be set:"
  log "INFO" "  GRPC_SERVER_PORT=$PORT"
  log "INFO" "  GRPC_HELLO_BACKEND=$BACKEND_HOST"
  log "INFO" "  GRPC_HELLO_BACKEND_PORT=$BACKEND_PORT"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    log "INFO" "  GRPC_HELLO_SECURE=Y"
  fi
  
  # Log the command being executed
  log "INFO" "Server command: $SERVER_CMD"
  
  # Setup cleanup handlers
  log "INFO" "Setting up signal handlers for graceful shutdown"
  setup_cleanup_handlers
  
  # Execute server command
  log "INFO" "=========================================="
  log "INFO" "Step 7/7: Starting proxy server"
  log "INFO" "=========================================="
  # Note: We use eval here to properly handle the environment variables in the command string
  eval "$SERVER_CMD" &
  SERVER_PID=$!
  
  # Track the process
  track_process "$SERVER_PID"
  
  log "INFO" "Proxy server started successfully"
  log "INFO" "  Process ID: $SERVER_PID"
  log "INFO" "  Listening on: localhost:$PORT"
  log "INFO" "  Forwarding to: $BACKEND_HOST:$BACKEND_PORT"
  log "INFO" "  Security: $(if [[ "$TLS_ENABLED" == "true" ]]; then echo "TLS enabled"; else echo "Insecure"; fi)"
  log "INFO" "=========================================="
  log "INFO" "Server is running. Press Ctrl+C to stop."
  log "INFO" "=========================================="
  
  # Wait for the server process
  wait "$SERVER_PID" || true
  
  log "INFO" "Proxy server stopped"
  log "INFO" "Script completed at: $(date '+%Y-%m-%d %H:%M:%S')"
}

# Run main function
main "$@"
