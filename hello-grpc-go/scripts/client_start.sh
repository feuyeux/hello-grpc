#!/usr/bin/env bash
# Client start script for Go gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Set Go module mode
export GO111MODULE="on"

# Logging functions
log_info() { echo "[CLIENT] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Default configuration
USE_TLS=false
ADDITIONAL_ARGS=""

# Set GOPATH based on OS
if [ "$(uname)" == "Darwin" ] || [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    export GOPATH=$GOPATH:${PWD}
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
    windows_path=$GOPATH
    linux_path=$(echo "$windows_path" | sed 's/^\([a-zA-Z]\):/\/\1/' | sed 's/\\/\//g')
    export GOPATH=$linux_path:${PWD}
fi

# Process command line arguments
while [[ $# -gt 0 ]]; do
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
    --count=*)
        COUNT="${1#*=}"
        ADDITIONAL_ARGS="$ADDITIONAL_ARGS --count=$COUNT"
        shift
        ;;
    --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tls                 Enable TLS communication"
        echo "  --addr=HOST:PORT      Server address to connect to (default: 127.0.0.1:9996)"
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

log_info "Starting Go gRPC client..."

# Build the command
CMD="go run client/proto_client.go"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
    export GRPC_HELLO_SECURE=Y
    log_info "TLS enabled"
    CMD="$CMD --tls $ADDITIONAL_ARGS"
else
    [ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
