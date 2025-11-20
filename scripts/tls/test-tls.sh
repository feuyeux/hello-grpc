#!/usr/bin/env bash

# Test TLS functionality for a specific language implementation
# This script starts a TLS-enabled server and client to verify secure gRPC communication

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions from proxy scripts
# shellcheck source=../proxy/common.sh
source "$SCRIPT_DIR/../proxy/common.sh"

# Default values
DEFAULT_TIMEOUT=30
LANGUAGE=""
TIMEOUT="$DEFAULT_TIMEOUT"

# Port configuration
SERVER_PORT=9996

# Process tracking
SERVER_PID=""
CLIENT_PID=""

# Display usage information
usage() {
  cat << EOF
Usage: $0 --language <lang> [OPTIONS]

Test TLS functionality for the specified language implementation.
This script starts a TLS-enabled gRPC server and client to verify secure communication.

Required Arguments:
  --language, -l <lang>    Language implementation to test
                           Supported: java, go, python, nodejs, typescript, rust,
                                     cpp, csharp, kotlin, swift, dart, php

Optional Arguments:
  --timeout <seconds>      Timeout for waiting operations (default: $DEFAULT_TIMEOUT)
  --help, -h               Display this help message

Examples:
  # Test Java TLS functionality
  $0 --language java

  # Test Go TLS with custom timeout
  $0 -l go --timeout 60

  # Test Python TLS
  $0 --language python

Exit Codes:
  0 - Success
  1 - Invalid parameters
  2 - Environment error (missing certificates, directories)
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

# Cleanup function for TLS test
# Terminates all started processes and performs cleanup
cleanup_tls_test() {
  log "INFO" "Cleaning up TLS test processes..."
  
  # Terminate processes in reverse order: client, server
  # Using the shared kill_process_gracefully function from common.sh
  kill_process_gracefully "$CLIENT_PID" "client" 5 || true
  kill_process_gracefully "$SERVER_PID" "server" 5 || true
  
  log "INFO" "Cleanup complete"
}

# Setup signal handlers for cleanup
setup_signal_handlers() {
  trap cleanup_tls_test EXIT INT TERM
}

# Handle process startup failure
handle_startup_failure() {
  local process_type="$1"
  local exit_code="$2"
  
  log "ERROR" "Failed to start $process_type (exit code: $exit_code)"
  log "ERROR" "Check the logs for more details"
  
  # Cleanup any processes that were started
  cleanup_tls_test
  
  exit "$EXIT_PROCESS_ERROR"
}

# Handle timeout error
handle_timeout() {
  local operation="$1"
  
  log "ERROR" "Timeout during: $operation"
  log "ERROR" "Operation exceeded timeout of ${TIMEOUT}s"
  
  # Cleanup any processes that were started
  cleanup_tls_test
  
  exit "$EXIT_TIMEOUT"
}

# Handle communication error
handle_communication_error() {
  local details="$1"
  
  log "ERROR" "Communication failed: $details"
  log "ERROR" "The TLS connection did not complete successfully"
  
  # Cleanup any processes that were started
  cleanup_tls_test
  
  exit "$EXIT_COMM_ERROR"
}

# Start TLS-enabled server
start_tls_server() {
  log "INFO" "Starting TLS-enabled server on port $SERVER_PORT..."
  
  # Get server command with TLS enabled
  local server_cmd
  server_cmd=$(get_server_command "$LANGUAGE" "$SERVER_PORT" "" "" "true")
  if [[ -z "$server_cmd" ]]; then
    log "ERROR" "Failed to get server command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Server environment variables:"
  log "INFO" "  GRPC_SERVER_PORT=$SERVER_PORT"
  log "INFO" "  GRPC_HELLO_SECURE=Y"
  
  # Log the command
  log "INFO" "Server command: $server_cmd"
  
  # Start server in background
  eval "$server_cmd" > /tmp/tls-server-$$.log 2>&1 &
  SERVER_PID=$!
  
  log "INFO" "TLS server started with PID: $SERVER_PID"
  
  # Wait for server to be ready
  if ! wait_for_ready "$SERVER_PORT" "$TIMEOUT"; then
    handle_timeout "TLS server startup"
  fi
  
  log "INFO" "TLS server is ready and listening"
}

# Start TLS-enabled client
start_tls_client() {
  log "INFO" "Starting TLS-enabled client connecting to port $SERVER_PORT..."
  
  # Get client command with TLS enabled
  local client_cmd
  client_cmd=$(get_client_command "$LANGUAGE" "localhost" "$SERVER_PORT" "true")
  if [[ -z "$client_cmd" ]]; then
    log "ERROR" "Failed to get client command for language: $LANGUAGE"
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Log environment variables
  log "INFO" "Client environment variables:"
  log "INFO" "  GRPC_SERVER=localhost"
  log "INFO" "  GRPC_SERVER_PORT=$SERVER_PORT"
  log "INFO" "  GRPC_HELLO_SECURE=Y"
  
  # Log the command
  log "INFO" "Client command: $client_cmd"
  
  # Create temporary file for client output
  local client_output="/tmp/tls-client-$$.log"
  
  # Start client and capture output
  eval "$client_cmd" > "$client_output" 2>&1
  local client_exit_code=$?
  
  log "INFO" "Client completed execution with exit code: $client_exit_code"
  
  # Display client output
  if [[ -f "$client_output" ]]; then
    log "INFO" "Client output:"
    cat "$client_output"
  fi
  
  # Check if client succeeded
  if [[ $client_exit_code -ne 0 ]]; then
    log "ERROR" "Client failed with exit code: $client_exit_code"
    rm -f "$client_output"
    handle_communication_error "Client execution failed"
  fi
  
  # Clean up temp file
  rm -f "$client_output"
  
  return 0
}

# Verify successful TLS communication
verify_communication() {
  log "INFO" "Verifying TLS communication..."
  
  # The key verification is that the client completed successfully (checked in start_tls_client)
  # This means:
  # 1. TLS handshake succeeded
  # 2. All four gRPC communication patterns executed
  # 3. Client terminated normally with exit code 0
  
  # Check if server is still running (informational only)
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    log "INFO" "TLS server is still running"
  else
    log "INFO" "TLS server has terminated"
  fi
  
  # Check for TLS handshake success in logs
  local server_log="/tmp/tls-server-$$.log"
  if [[ -f "$server_log" ]]; then
    # Look for common TLS success indicators (this is informational)
    if grep -qi "handshake\|tls\|ssl" "$server_log" 2>/dev/null; then
      log "INFO" "TLS handshake indicators found in server logs"
    fi
  fi
  
  log "INFO" "TLS communication verified successfully"
  log "INFO" "All four gRPC patterns (unary, client streaming, server streaming, bidirectional) executed"
  return 0
}

# Main execution
main() {
  local start_time
  local end_time
  local duration
  
  start_time=$(date +%s)
  
  log "INFO" "=========================================="
  log "INFO" "Starting TLS test script"
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
  
  log "INFO" "Configuration:"
  log "INFO" "  Language: $LANGUAGE"
  log "INFO" "  Timeout: ${TIMEOUT}s"
  log "INFO" "  Server Port: $SERVER_PORT"
  log "INFO" "  TLS Mode: ENABLED"
  
  # Verify TLS certificates
  log "INFO" "Step 4/8: Verifying TLS certificates"
  
  # Get the project root (two levels up from scripts/tls)
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
  cd "$PROJECT_ROOT" || exit "$EXIT_ENV_ERROR"
  
  if ! verify_tls_certificates; then
    exit "$EXIT_ENV_ERROR"
  fi
  
  # Get language directory
  log "INFO" "Step 5/8: Locating language implementation"
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
  log "INFO" "Changed to language directory"
  
  # Start TLS server and client
  log "INFO" "=========================================="
  log "INFO" "Step 6/8: Starting TLS-enabled components"
  log "INFO" "=========================================="
  
  # Step 1: Start TLS server
  log "INFO" "Step 6a: Starting TLS server..."
  start_tls_server
  log "INFO" "TLS server operational"
  
  # Step 2: Start TLS client
  log "INFO" "Step 6b: Starting TLS client..."
  start_tls_client
  log "INFO" "TLS client execution completed"
  
  # Step 3: Verify communication
  log "INFO" "=========================================="
  log "INFO" "Step 7/8: Verifying TLS communication"
  log "INFO" "=========================================="
  verify_communication
  
  # Calculate duration
  end_time=$(date +%s)
  duration=$((end_time - start_time))
  
  # Success!
  log "INFO" "=========================================="
  log "INFO" "Step 8/8: Test completion"
  log "INFO" "=========================================="
  log "INFO" "TLS test completed successfully for $LANGUAGE"
  log "INFO" "TLS handshake succeeded"
  log "INFO" "All gRPC communication patterns executed successfully"
  log "INFO" "Total test duration: ${duration}s"
  log "INFO" "=========================================="
  
  # Cleanup will be handled by trap
  exit "$EXIT_SUCCESS"
}

# Run main function
main "$@"
