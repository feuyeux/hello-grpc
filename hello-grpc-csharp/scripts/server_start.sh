#!/usr/bin/env bash
# Server start script for C# gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}/HelloServer" || exit

# Logging functions
log_info() { echo "[SERVER] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Default configuration
USE_TLS=false
ADDITIONAL_ARGS=""
DOTNET_CMD="dotnet"

# Special handling for MacOS ARM64
if [ "$(uname -m)" = "arm64" ] && [ "$(uname)" = "Darwin" ]; then
  export DOTNET_RUNNING_IN_APPLE_SILICON=true
fi

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
    echo "  --addr=HOST:PORT      Server address to bind (default: 0.0.0.0:9996)"
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

log_info "Starting C# gRPC server..."

# Clean and build
dotnet clean
dotnet build

# If port is specified but addr is not, add default bind address
if [ -z "$(echo "$ADDITIONAL_ARGS" | grep -o 'addr=')" ]; then
  ADDITIONAL_ARGS="$ADDITIONAL_ARGS --addr=0.0.0.0:9996"
fi

# Build the command
CMD="$DOTNET_CMD run"

# Set the TLS environment variable if enabled
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
  log_info "TLS enabled"
fi

# Pass additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD -- $ADDITIONAL_ARGS"

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
