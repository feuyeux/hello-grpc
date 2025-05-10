#!/usr/bin/env sh
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit

cd client
# 替换为distTar任务来生成tar文件
gradle clean distTar

# Default configuration
USE_TLS=false
ADDITIONAL_ARGS=""

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
  --count=*)
    COUNT="${1#*=}"
    ADDITIONAL_ARGS="$ADDITIONAL_ARGS --count=$COUNT"
    shift
    ;;
  --help)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --tls                 Enable TLS communication"
    echo "  --addr=HOST:PORT      Specify server address to connect to (default: 127.0.0.1:9996)"
    echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
    echo "  --count=NUMBER        Number of requests to send"
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

# 解压tar文件到build/install目录（如果尚未解压）
if [ ! -d "build/install/client" ]; then
  mkdir -p build/install
  tar -xf build/distributions/client.tar -C build/install
fi

# Build the command
CMD="build/install/client/bin/client"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
  CMD="$CMD --tls $ADDITIONAL_ARGS"
else
  [ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
echo "Running: $CMD"
eval "$CMD"
