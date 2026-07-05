#!/bin/bash
# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT" || exit

# Pre-flight: ensure the PHP gRPC C-extension is available
# shellcheck source=check_grpc_ext.sh
source "$SCRIPT_DIR/check_grpc_ext.sh"
check_grpc_extension || exit 1

# ── argument parsing ───────────────────────────────────────────────────
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
# Run PHP with modified error reporting to hide deprecated warnings
mkdir -p ./log

# Construct the PHP command with all needed settings
# Inject -d extension=… when the extension was found but not enabled by default
PHP_CMD="php $GRPC_EXT_FLAG \
    -d error_reporting='E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED' \
    -d display_errors=1 \
    -d display_startup_errors=1 \
    -d log_errors=1 \
    -d error_log=./log/php_server_errors.log \
    hello_server.php"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
  PHP_CMD="$PHP_CMD --tls $ADDITIONAL_ARGS"
else
  [ -n "$ADDITIONAL_ARGS" ] && PHP_CMD="$PHP_CMD $ADDITIONAL_ARGS"
fi

# Execute the server.
# The gRPC C extension may intercept SIGINT internally, preventing the PHP
# signal handler (and Ctrl-C) from working reliably on macOS.  We run the
# PHP process in the background and let the shell trap SIGINT/SIGTERM to
# forward SIGKILL, which cannot be caught or ignored.
echo "Running server in foreground with full log output..."
eval "$PHP_CMD" &
SERVER_PID=$!

# Forward termination signals to the PHP process as SIGKILL
cleanup() {
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -KILL "$SERVER_PID" 2>/dev/null
    wait "$SERVER_PID" 2>/dev/null
  fi
}
trap cleanup SIGINT SIGTERM EXIT

# Wait for the server process to exit
wait "$SERVER_PID"