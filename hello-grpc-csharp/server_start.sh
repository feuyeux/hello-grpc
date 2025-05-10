#!/usr/bin/env sh
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1 || exit
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit
cd HelloServer || exit
dotnet clean
dotnet build

# Default configuration
USE_TLS=false
ADDITIONAL_ARGS=""
DOTNET_CMD="dotnet"

# 对于 MacOS ARM64 设置特殊环境变量
if [ "$(uname -m)" = "arm64" ] && [ "$(uname)" = "Darwin" ]; then
  # 设置环境变量，告诉 .NET 应用程序这是一个特殊环境
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
  --help)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --tls                 Enable TLS communication"
    echo "  --addr=HOST:PORT      Specify server address (default: 127.0.0.1:9996)"
    echo "  --port=PORT           Specify server port only (default: 9996)"
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

# If port is specified but addr is not, add port to additional args
if [ -z "$(echo "$ADDITIONAL_ARGS" | grep -o 'addr=')" ]; then
  ADDITIONAL_ARGS="$ADDITIONAL_ARGS --addr=0.0.0.0"
fi

# Build the command
CMD="$DOTNET_CMD run"

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
