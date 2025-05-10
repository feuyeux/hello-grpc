#!/bin/bash
# shellcheck disable=SC2046
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
export GO111MODULE="on"

# Preparation steps
echo "Checking Go gRPC dependencies..."
# Check if go.mod exists, initialize if needed
if [ ! -f "go.mod" ]; then
  echo "Initializing Go module..."
  go mod init github.com/feuyeux/hello-grpc-go
fi

# Download dependencies if needed
echo "Downloading Go dependencies..."
go mod tidy

if [ "$(uname)" == "Darwin" ] || [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
  export GOPATH=$GOPATH:${PWD}
  echo "[Mac OS X or Linux] GOPATH=$GOPATH"
elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ] || [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
  windows_path=$GOPATH
  linux_path=$(echo "$windows_path" | sed 's/^\([a-zA-Z]\):/\/\1/' | sed 's/\\/\//g')
  export GOPATH=$linux_path:${PWD}
  echo "[Windows] GOPATH=$GOPATH"
fi

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
CMD="go run server/proto_server.go"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
  CMD="$CMD --tls $ADDITIONAL_ARGS"
else
  [ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
echo "Running: $CMD"
eval "$CMD"
