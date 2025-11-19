#!/usr/bin/env bash
# Server start script for Kotlin gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Logging functions
log_info() { echo "[SERVER] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Build only server module using root gradle
log_info "Building server module..."
gradle :server:clean :server:installDist

# Default configuration
USE_TLS=false
ADDITIONAL_ARGS=""

# Process command line arguments
while [ $# -gt 0 ]; do
  case $1 in
  --tls)
    USE_TLS=true
    shift
    ;;
  --addr=*)
    ADDR="${1#*=}"
    ADDITIONAL_ARGS="$ADDITIONAL_ARGS --addr=$ADDR"
    shift
    ;;
  --log=*)
    LOG_LEVEL="${1#*=}"
    ADDITIONAL_ARGS="$ADDITIONAL_ARGS --log=$LOG_LEVEL"
    shift
    ;;
  --help|-h)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --tls                 Enable TLS communication"
    echo "  --addr=HOST:PORT      Server address to bind (default: 127.0.0.1:9996)"
    echo "  --log=LEVEL           Set log level (trace|debug|info|warn|error)"
    echo "  --help, -h            Show this help message"
    exit 0
    ;;
  *)
    log_error "Unknown option: $1"
    echo "Use --help to see available options"
    exit 1
    ;;
  esac
done

# Check if build succeeded
if [ ! -d "server/build/install/server" ]; then
  log_error "Build failed or server distribution not found"
  exit 1
fi

log_info "Starting Kotlin gRPC server..."

# Build the command
CMD="server/build/install/server/bin/server"

# Set the TLS environment variable if enabled
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
  log_info "TLS enabled"
  
  # Set certificate path - try project local first
  PROJECT_CERT_PATH="$(cd "$PROJECT_ROOT/../docker/tls/server_certs" 2>/dev/null && pwd)"
  
  if [ -n "$PROJECT_CERT_PATH" ] && [ -d "$PROJECT_CERT_PATH" ] && [ -f "$PROJECT_CERT_PATH/myssl_root.cer" ]; then
    export CERT_BASE_PATH="$PROJECT_CERT_PATH"
    log_info "Using project certificates: $CERT_BASE_PATH"
  else
    # Fall back to system certificate path
    if [[ "$(uname)" == "Darwin" ]] || [[ "$(uname)" == "Linux" ]]; then
      export CERT_BASE_PATH="/var/hello_grpc/server_certs"
    else
      export CERT_BASE_PATH="d:\\garden\\var\\hello_grpc\\server_certs"
    fi
    log_info "Using system certificates: $CERT_BASE_PATH"
  fi
  
  # Check if certificate directory exists
  if [ ! -d "$CERT_BASE_PATH" ]; then
    log_error "Certificate directory does not exist: $CERT_BASE_PATH"
    exit 1
  fi
fi

# Add additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
