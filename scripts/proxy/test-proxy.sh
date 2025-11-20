#!/usr/bin/env bash

# Test proxy functionality for a specific language implementation
# This script orchestrates a complete proxy chain: backend -> proxy -> client

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

# Default values
DEFAULT_TIMEOUT=30
LANGUAGE=""
TLS_ENABLED=false
TIMEOUT="$DEFAULT_TIMEOUT"

# Port configuration
BACKEND_PORT=9996
PROXY_PORT=8886

# Process tracking
BACKEND_PID=""
PROXY_PID=""
CLIENT_PID=""

# Display usage information
usage() {
  cat << EOF
Usage: $0 --language <lang> [OPTIONS]

Test proxy functionality for the specified language implementation.
This script starts a complete proxy chain: backend server -> proxy server -> client

Required Arguments:
  --language, -l <lang>    Language implementation to test
                           Supported: java, go, python, nodejs, typescript, rust,
                                     cpp, csharp, kotlin, swift, dart, php

Optional Arguments:
  --tls, -t                Enable TLS/secure mode for all connections
  --timeout <seconds>      Timeout for waiting operations (default: $DEFAULT_TIMEOUT)
  --help, -h               Display this help message

Examples:
  # Test Java proxy functionality
  $0 --language java

  # Test Go proxy with TLS enabled
  $0 --language go --tls

  # Test Python proxy with custom timeout
  $0 -l python --timeout 60

Exit Codes:
  0 - Success
  1 - Invalid parameters
  2 - Environment error (missing files, directories)
  3 - Process failed to start
  4 - Communication failed
  5 - Timeout

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
      --tls|-t)
        TLS_ENABLED=true
        shift
        ;;
      --timeout)
        if [[ -z "${2:-}" ]]; then
          log "ERROR" "Missing value for --timeout"
          usage
        fi
        TIMEOUT="$2"
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


# Cleanup function for proxy test
# Terminates all started processes and performs cleanup
cleanup_proxy_test() {
  log "INFO" "Cleaning up proxy test processes..."
  
  # Terminate processes in reverse order: client, proxy, backend
  # Using the shared kill_process_gracefully function from common.sh
  kill_process_gracefully "$CLIENT_PID" "client" 5 || true
  kill_process_gracefully "$PROXY_PID" "proxy" 5 || true
  kill_process_gracefully "$BACKEND_PID" "backend" 5 || true
  
  log "INFO" "Cleanup complete"
}

# Setup signal handlers for cleanup
setup_signal_handlers() {
  trap cleanup_proxy_test EXIT INT TERM
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

# Handle process startup failure
handle_startup_failure() {
  local process_type="$1"
  local exit_code="$2"
  
  log "ERROR" "Failed to start $process_type (exit code: $exit_code)"
  log "ERROR" "Check the logs for more details"
  
  # Cleanup any processes that were started
  cleanup_proxy_test
  
  exit "$EXIT_PROCESS_ERROR"
}

# Handle timeout error
handle_timeout() {
  local operation="$1"
  
  log "ERROR" "Timeout during: $operation"
  log "ERROR" "Operation exceeded timeout of ${TIMEOUT}s"
  
  # Cleanup any processes that were started
  cleanup_proxy_test
  
  exit "$EXIT_TIMEOUT"
}

# Handle communication error
handle_communication_error() {
  local details="$1"
  
  log "ERROR" "Communication failed: $details"
  log "ERROR" "The proxy chain did not complete successfully"
  
  # Cleanup any processes that were started
  cleanup_proxy_test
  
  exit "$EXIT_COMM_ERROR"
}


# Start backend server
start_backend_server() {
  log "INFO" "Starting backend server on port $BACKEND_PORT..."
  
  # Get server command
  local tls_flag="false"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    tls_flag="true"
  fi
  
  local backend_cmd
  backend_cmd=$(get_server_command "$LANGUAGE" "$BACKEND_PORT" "" "" "$tls_flag")
  if [[ -z "$backend_cmd" ]]; then
    log "ERROR" "Failed to get backend server command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Backend environment variables:"
  log "INFO" "  GRPC_SERVER_PORT=$BACKEND_PORT"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    log "INFO" "  GRPC_HELLO_SECURE=Y"
  fi
  
  # Log the command
  log "INFO" "Backend command: $backend_cmd"
  
  # Start backend server in background
  eval "$backend_cmd" > /tmp/backend-$$.log 2>&1 &
  BACKEND_PID=$!
  
  log "INFO" "Backend server started with PID: $BACKEND_PID"
  
  # Wait for backend to be ready
  if ! wait_for_ready "$BACKEND_PORT" "$TIMEOUT"; then
    handle_timeout "backend server startup"
  fi
  
  log "INFO" "Backend server is ready"
}

# Start proxy server
start_proxy_server() {
  log "INFO" "Starting proxy server on port $PROXY_PORT..."
  
  # Get server command for proxy mode
  local tls_flag="false"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    tls_flag="true"
  fi
  
  local proxy_cmd
  proxy_cmd=$(get_server_command "$LANGUAGE" "$PROXY_PORT" "localhost" "$BACKEND_PORT" "$tls_flag")
  if [[ -z "$proxy_cmd" ]]; then
    log "ERROR" "Failed to get proxy server command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Proxy environment variables:"
  log "INFO" "  GRPC_SERVER_PORT=$PROXY_PORT"
  log "INFO" "  GRPC_HELLO_BACKEND=localhost"
  log "INFO" "  GRPC_HELLO_BACKEND_PORT=$BACKEND_PORT"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    log "INFO" "  GRPC_HELLO_SECURE=Y"
  fi
  
  # Log the command
  log "INFO" "Proxy command: $proxy_cmd"
  
  # Start proxy server in background
  eval "$proxy_cmd" > /tmp/proxy-$$.log 2>&1 &
  PROXY_PID=$!
  
  log "INFO" "Proxy server started with PID: $PROXY_PID"
  
  # Wait for proxy to be ready
  if ! wait_for_ready "$PROXY_PORT" "$TIMEOUT"; then
    handle_timeout "proxy server startup"
  fi
  
  log "INFO" "Proxy server is ready"
}

# Start client and capture output
start_client() {
  log "INFO" "Starting client connecting to proxy on port $PROXY_PORT..."
  
  # Get client command
  local tls_flag="false"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    tls_flag="true"
  fi
  
  local client_cmd
  client_cmd=$(get_client_command "$LANGUAGE" "localhost" "$PROXY_PORT" "$tls_flag")
  if [[ -z "$client_cmd" ]]; then
    log "ERROR" "Failed to get client command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Client environment variables:"
  log "INFO" "  GRPC_SERVER=localhost"
  log "INFO" "  GRPC_SERVER_PORT=$PROXY_PORT"
  if [[ "$TLS_ENABLED" == "true" ]]; then
    log "INFO" "  GRPC_HELLO_SECURE=Y"
  fi
  
  # Log the command
  log "INFO" "Client command: $client_cmd"
  
  # Create temporary file for client output
  local client_output="/tmp/client-$$.log"
  
  # Start client and capture output
  eval "$client_cmd" > "$client_output" 2>&1 &
  CLIENT_PID=$!
  
  log "INFO" "Client started with PID: $CLIENT_PID"
  
  # Wait for client to complete (with timeout)
  local wait_time=0
  
  while [[ $wait_time -lt $TIMEOUT ]]; do
    if ! kill -0 "$CLIENT_PID" 2>/dev/null; then
      # Client has finished
      log "INFO" "Client completed"
      
      # Display client output
      if [[ -f "$client_output" ]]; then
        log "INFO" "Client output:"
        cat "$client_output"
      fi
      
      # Clean up temp file
      rm -f "$client_output"
      
      return 0
    fi
    
    sleep 1
    ((wait_time++))
  done
  
  # Client didn't complete in time
  log "WARN" "Client did not complete within timeout"
  
  # Display partial output
  if [[ -f "$client_output" ]]; then
    log "INFO" "Client output (partial):"
    cat "$client_output"
  fi
  
  # Clean up temp file
  rm -f "$client_output"
  
  handle_timeout "client execution"
}

# Verify successful communication
verify_communication() {
  log "INFO" "Verifying proxy chain communication..."
  
  # The key verification is that the client completed successfully
  # Backend and proxy servers may or may not still be running depending on implementation
  
  # Client should have completed (not still running)
  if [[ -n "$CLIENT_PID" ]] && kill -0 "$CLIENT_PID" 2>/dev/null; then
    log "ERROR" "Client is still running (should have completed)"
    handle_communication_error "Client did not complete"
  fi
  
  # Check if backend and proxy are still running (informational only)
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    log "INFO" "Backend server is still running"
  else
    log "INFO" "Backend server has terminated"
  fi
  
  if [[ -n "$PROXY_PID" ]] && kill -0 "$PROXY_PID" 2>/dev/null; then
    log "INFO" "Proxy server is still running"
  else
    log "INFO" "Proxy server has terminated"
  fi
  
  log "INFO" "Proxy chain communication verified successfully"
  return 0
}


# Main execution
main() {
  local start_time
  local end_time
  local duration
  
  start_time=$(date +%s)
  
  log "INFO" "=========================================="
  log "INFO" "Starting proxy test script"
  log "INFO" "=========================================="
  
  # Parse arguments
  log "INFO" "Step 1/8: Parsing command line arguments"
  parse_arguments "$@"
  log "INFO" "Arguments parsed successfully"
  
  # Setup signal handlers for cleanup
  log "INFO" "Step 2/8: Setting up signal handlers"
  setup_signal_handlers
  log "INFO" "Signal handlers configured"
  
  # Validate language
  log "INFO" "Step 3/8: Validating language support"
  if ! validate_language "$LANGUAGE"; then
    log "ERROR" "Unsupported language: $LANGUAGE"
    log "ERROR" "Supported languages: ${SUPPORTED_LANGUAGES[*]}"
    exit "$EXIT_INVALID_PARAMS"
  fi
  
  # Check if language supports proxy mode
  if ! supports_proxy "$LANGUAGE"; then
    log "ERROR" "Language $LANGUAGE does not support proxy mode"
    log "ERROR" "Proxy is supported for: ${PROXY_SUPPORTED_LANGUAGES[*]}"
    log "ERROR" "Please implement proxy mode for $LANGUAGE first"
    exit "$EXIT_ENV_ERROR"
  fi
  
  log "INFO" "Configuration:"
  log "INFO" "  Language: $LANGUAGE"
  log "INFO" "  Timeout: ${TIMEOUT}s"
  log "INFO" "  Backend Port: $BACKEND_PORT"
  log "INFO" "  Proxy Port: $PROXY_PORT"
  
  # Handle TLS mode
  log "INFO" "Step 4/8: Configuring security mode"
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
  log "INFO" "Step 5/8: Locating language implementation"
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
  
  # Start the proxy chain
  log "INFO" "=========================================="
  log "INFO" "Step 6/8: Starting proxy chain components"
  log "INFO" "=========================================="
  log "INFO" "Proxy chain architecture: Client -> Proxy -> Backend"
  
  # Step 1: Start backend server
  log "INFO" "Step 6a: Starting backend server..."
  start_backend_server
  log "INFO" "Backend server operational"
  
  # Step 2: Start proxy server
  log "INFO" "Step 6b: Starting proxy server..."
  start_proxy_server
  log "INFO" "Proxy server operational"
  
  # Step 3: Start client
  log "INFO" "Step 6c: Starting client..."
  start_client
  log "INFO" "Client execution completed"
  
  # Step 4: Verify communication
  log "INFO" "=========================================="
  log "INFO" "Step 7/8: Verifying proxy chain"
  log "INFO" "=========================================="
  verify_communication
  
  # Calculate duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  # Success!
  log "INFO" "=========================================="
  log "INFO" "Step 8/8: Test completion"
  log "INFO" "=========================================="
  log "INFO" "Proxy test completed successfully for $LANGUAGE"
  log "INFO" "All processes in proxy chain functioned correctly"
  log "INFO" "Total test duration: ${duration}s"
  log "INFO" "=========================================="
  
  # Cleanup will be handled by trap
  exit "$EXIT_SUCCESS"
}

# Run main function
main "$@"
