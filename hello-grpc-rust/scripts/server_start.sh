#!/bin/bash
# Resolve SCRIPT_DIR (where this script lives) and PROJECT_ROOT (its
# parent, where Cargo.toml lives). The previous version did
#   cd "$(dirname "$0")/..."
# which landed us in $SCRIPT_DIR, not $PROJECT_ROOT; subsequent
# `cargo check` and `grep Cargo.toml` then operated on a directory
# with no Cargo.toml and reported "No such file or directory".
SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd -P)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd -P)"
cd "${PROJECT_ROOT}" || exit

# ts: print "[HH:MM:SS]" so the user can see which step is taking time.
ts() { date "+[%H:%M:%S]"; }
echo "$(ts) Checking Rust setup and dependencies..."

# Check if cargo is installed
if ! command -v cargo &>/dev/null; then
  echo "Error: Rust's Cargo is not installed or not in PATH"
  echo "Please install Rust from https://rustup.rs/ and try again"
  exit 1
fi
echo "$(ts) cargo found: $(command -v cargo)"

# Sanity check: does the binary name we are about to run actually exist
# in Cargo.toml? Without this, a typo or stale workspace silently drops
# the user into "cargo run" with nothing to run, which looks like a hang.
if ! grep -q 'name = "proto-server"' Cargo.toml; then
  echo "Error: no bin target named 'proto-server' in $(pwd)/Cargo.toml"
  echo "Available [[bin]] targets:"
  grep -E 'name = "' Cargo.toml || echo "  (none found)"
  exit 1
fi
echo "$(ts) bin target 'proto-server' found in Cargo.toml"

# Build project dependencies. Removed --quiet so cargo's "Compiling X v..."
# / "Downloading Y" lines stream to the terminal; without them, the
# first cold compile looks indistinguishable from a hang.
echo "$(ts) Running 'cargo check' (streaming output, may take several minutes on cold cache)..."
cargo check
echo "$(ts) cargo check finished"

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
echo "$(ts) Building run command"
CMD="cargo run --bin proto-server"

# Set the TLS environment variable if enabled
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
  echo "TLS enabled via GRPC_HELLO_SECURE=Y"
  echo "Using certificates from /var/hello_grpc/server_certs/"
fi

# Pass additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD -- $ADDITIONAL_ARGS"

# Execute the command
echo "$(ts) Starting server: $CMD"
echo "$(ts) NOTE: cargo run blocks until the server process exits. If the"
echo "$(ts) server binds to 127.0.0.1:9996 successfully it will appear to"
echo "$(ts) 'hang' — that is the server running, not a hang. To stop it,"
echo "$(ts) press Ctrl+C in this terminal, or run:"
echo "$(ts)   ./scripts/stop_server.sh"
eval "$CMD"
