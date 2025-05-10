#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

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
  --stream=*)
    STREAM_TYPE="${1#*=}"
    shift
    ;;
  --data=*)
    DATA="${1#*=}"
    shift
    ;;
  --meta=*)
    META="${1#*=}"
    shift
    ;;
  --help)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --tls                 Enable TLS communication"
    echo "  --addr=HOST:PORT      Specify server address to connect to (default: 127.0.0.1:9996)"
    echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
    echo "  --count=NUMBER        Number of requests to send"
    echo "  --stream=TYPE         Stream type (client-streaming, server-streaming, bidirectional)"
    echo "  --data=VALUE          Data value to send"
    echo "  --meta=VALUE          Metadata value to send"
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
# Create a log directory if it doesn't exist
mkdir -p ./log

# Prepare parameters for client
PARAMS=""
[ -n "$DATA" ] && PARAMS="$DATA"
[ -z "$PARAMS" ] && PARAMS="0"

[ -n "$META" ] && PARAMS="$PARAMS $META"
[ -z "$META" ] && PARAMS="$PARAMS hello"

[ -n "$STREAM_TYPE" ] && PARAMS="$PARAMS $STREAM_TYPE"

# Set environment variables for TLS if needed
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
fi

# Set server address if specified
if [ -n "$ADDR" ]; then
  export GRPC_SERVER="${ADDR%:*}"
  export GRPC_SERVER_PORT="${ADDR#*:}"
fi

# Create log directory
mkdir -p ./log

# Construct the PHP command with all needed settings
PHP_CMD="php -d error_reporting=E_ALL \
    -d display_errors=1 \
    -d display_startup_errors=1 \
    -d log_errors=1 \
    -d error_log=./log/php_client_errors.log \
    hello_client.php $PARAMS"

# Execute the command in foreground with full log output
echo "Running client in foreground with full log output..."
eval "$PHP_CMD"
