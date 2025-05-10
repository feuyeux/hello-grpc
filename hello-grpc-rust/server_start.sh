#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

# Preparation steps
echo "Checking Rust setup and dependencies..."
# Check if cargo is installed
if ! command -v cargo &>/dev/null; then
  echo "Error: Rust's Cargo is not installed or not in PATH"
  echo "Please install Rust from https://rustup.rs/ and try again"
  exit 1
fi

# Check if the required crates are in Cargo.toml, if not present cargo will fetch them
echo "Building project dependencies (this may take a moment)..."
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
  --help)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --tls                 Enable TLS communication"
    echo "  --addr=HOST:PORT      Specify server address (default: 127.0.0.1:9996)"
    echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
    echo "  --help                Show this help message"
    exit 0
    ;;
  *)
    # Pass through any other arguments
    ADDITIONAL_ARGS="$ADDITIONAL_ARGS $1"
    shift
    ;;
  esac
done

# Build the command
CMD="cargo run --bin proto-server"

# Set the TLS environment variable if enabled instead of passing flag
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
  echo "TLS enabled via GRPC_HELLO_SECURE=Y"
fi

# Pass additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD -- $ADDITIONAL_ARGS"

# Execute the command
echo "Running: $CMD"
eval "$CMD"
