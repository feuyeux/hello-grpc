#!/bin/bash
# shellcheck disable=SC2155
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

# Preparation steps
echo "Checking Python gRPC dependencies..."
# Check if grpcio and protobuf are installed
if ! python3 -c "import grpc, google.protobuf" &>/dev/null; then
  echo "Installing required Python gRPC dependencies..."
  pip3 install grpcio grpcio-tools protobuf --upgrade
  echo "Dependencies installed successfully"
else
  echo "Python gRPC dependencies already installed"
fi

export PYTHONPATH=$(pwd)
export PYTHONPATH=$PYTHONPATH:$(pwd)/landing_pb2
alias python=python3
python -V
echo "PYTHONPATH=${PYTHONPATH}"

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

echo "Starting server..."

# Build the command
CMD="python server/protoServer.py"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
  CMD="$CMD --tls $ADDITIONAL_ARGS"
else
  [ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
echo "Running: $CMD"
eval "$CMD"
