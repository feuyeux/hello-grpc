#!/usr/bin/env bash
# Client start script for Rust gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Logging functions
log_info() { echo "[CLIENT] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Preparation steps
log_info "Checking Rust setup and dependencies..."
# Check if cargo is installed
if ! command -v cargo &>/dev/null; then
  log_error "Rust's Cargo is not installed or not in PATH"
  log_error "Please install Rust from https://rustup.rs/ and try again"
  exit 1
fi

# Check if the required crates are in Cargo.toml
log_info "Building project dependencies (this may take a moment)..."
cargo check --quiet

# Default configuration
USE_TLS=false
ADDITIONAL_ARGS=""

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

log_info "Starting Rust gRPC client..."

# Build the command
CMD="cargo run --bin proto-client"

# Set the TLS environment variable if enabled
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
  log_info "TLS enabled"
  log_info "Using certificates from /var/hello_grpc/client_certs/"
fi

# Pass additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD -- $ADDITIONAL_ARGS"

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
