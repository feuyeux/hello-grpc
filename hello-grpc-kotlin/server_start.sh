#!/usr/bin/env sh
SCRIPT_PATH="$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/"
cd "$SCRIPT_PATH" || exit

cd server
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

# 解压tar文件到build/install目录（如果尚未解压）
if [ ! -d "build/install/server" ]; then
  mkdir -p build/install
  tar -xf build/distributions/server.tar -C build/install
fi

# Build the command
CMD="build/install/server/bin/server"

# Set the TLS environment variable if enabled instead of passing flag
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE=Y
  echo "TLS enabled via GRPC_HELLO_SECURE=Y"
fi

# Add additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"

# Execute the command
echo "Running: $CMD"
eval "$CMD"
