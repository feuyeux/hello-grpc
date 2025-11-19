#!/usr/bin/env bash
# Server start script for Python gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Logging functions
log_info() { echo "[SERVER] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Check if virtual environment exists and activate it
if [ -d "venv" ]; then
  log_info "Activating virtual environment..."
  source venv/bin/activate
elif [ -d "../venv" ]; then
  log_info "Activating virtual environment from parent directory..."
  source ../venv/bin/activate
fi

# Preparation steps
log_info "Checking Python gRPC dependencies..."
# Check if grpcio and protobuf are installed
if ! python3 -c "import grpc, google.protobuf" &>/dev/null; then
  log_info "Installing required Python gRPC dependencies..."
  pip3 install grpcio grpcio-tools protobuf --upgrade
else
  log_info "Python gRPC dependencies already installed"
fi

export PYTHONPATH=$(pwd)
export PYTHONPATH=$PYTHONPATH:$(pwd)/landing_pb2
alias python=python3

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
  --help|-h)
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --tls                 Enable TLS communication"
    echo "  --addr=HOST:PORT      Server address to bind (default: 127.0.0.1:9996)"
    echo "  --log=LEVEL           Set log level (trace|debug|info|warn|error)"
    echo "  --help, -h            Show this help message"
    exit 0
    ;;
  *)
    log_error "Unknown option: $1"
    echo "Use --help to see available options"
    exit 1
    ;;
  esac
done

log_info "Starting Python gRPC server..."

# Build the command
CMD="python server/protoServer.py"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
  export GRPC_HELLO_SECURE="Y"
  log_info "TLS enabled"
  
  # Set certificate path based on OS
  if [[ "$(uname)" == "Darwin" ]] || [[ "$(uname)" == "Linux" ]]; then
    export CERT_BASE_PATH="/var/hello_grpc/server_certs"
  else
    export CERT_BASE_PATH="d:\\garden\\var\\hello_grpc\\server_certs"
  fi
  
  # Check if certificate directory exists
  if [ ! -d "$CERT_BASE_PATH" ]; then
    log_error "Certificate directory does not exist: $CERT_BASE_PATH"
    exit 1
  fi
  
  # Check if the required certificate files exist
  if [ ! -f "$CERT_BASE_PATH/cert.pem" ] || [ ! -f "$CERT_BASE_PATH/private.key" ] ||
     [ ! -f "$CERT_BASE_PATH/full_chain.pem" ] || [ ! -f "$CERT_BASE_PATH/myssl_root.cer" ]; then
    log_error "Required certificate files are missing in $CERT_BASE_PATH"
    log_error "Required files: cert.pem, private.key, full_chain.pem, myssl_root.cer"
    exit 1
  fi
  
  log_info "Using certificates from: $CERT_BASE_PATH"
  CMD="$CMD $ADDITIONAL_ARGS"
else
  [ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
