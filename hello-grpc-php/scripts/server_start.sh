#!/bin/bash
# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT" || exit

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
# 使用单引号正确处理错误报告级别表达式
PHP_CMD="php -d error_reporting='E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED' \
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

# Execute the command in foreground
echo "Running server in foreground with full log output..."
eval "$PHP_CMD"