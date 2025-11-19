#!/usr/bin/env bash
# Client start script for C++ gRPC project
set -e

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Logging functions
log_info() { echo "[CLIENT] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Default values
REBUILD=false
USE_TLS=false
ADDITIONAL_ARGS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild|-r)
            REBUILD=true
            shift
            ;;
        --tls)
            USE_TLS=true
            shift
            ;;
        --addr=*)
            ADDR="${1#*=}"
            ADDITIONAL_ARGS="$ADDITIONAL_ARGS --target=$ADDR"
            shift
            ;;
        --log=*)
            LOG_LEVEL="${1#*=}"
            ADDITIONAL_ARGS="$ADDITIONAL_ARGS --log=$LOG_LEVEL"
            shift
            ;;
        --count=*)
            COUNT="${1#*=}"
            ADDITIONAL_ARGS="$ADDITIONAL_ARGS --count=$COUNT"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --rebuild, -r         Rebuild the project before starting"
            echo "  --tls                 Enable TLS communication"
            echo "  --addr=HOST:PORT      Server address to connect to (default: localhost:9996)"
            echo "  --log=LEVEL           Set log level (trace|debug|info|warn|error)"
            echo "  --count=NUMBER        Number of requests to send"
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

log_info "Starting C++ gRPC client..."

# Rebuild if requested
if [ "${REBUILD}" = true ]; then
    log_info "Rebuilding project..."
    "${SCRIPT_DIR}/build.sh"
fi

# Check if binary exists
if [ ! -f "bazel-bin/hello_client" ]; then
    log_info "Binary not found, building project..."
    "${SCRIPT_DIR}/build.sh"
fi

# Set TLS environment variable if enabled
if [ "${USE_TLS}" = true ]; then
    export GRPC_HELLO_SECURE=Y
    log_info "TLS enabled"
fi

# Build command
CMD="bazel-bin/hello_client"
if [ -z "$ADDITIONAL_ARGS" ]; then
    CMD="$CMD --target=localhost:9996"
else
    CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
