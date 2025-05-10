#!/bin/bash
cd "$(
    cd "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)/" || exit

# Preparation steps
echo "Checking and installing dependencies if needed..."
if [ ! -d "node_modules" ] || [ ! -d "node_modules/@grpc" ]; then
    echo "Installing required gRPC dependencies..."
    # Check if package.json exists, create if not
    if [ ! -f "package.json" ]; then
        npm init -y
    fi
    npm install @grpc/grpc-js @grpc/proto-loader uuid winston
    echo "Dependencies installed successfully"
else
    echo "Dependencies already installed"
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

# Prepare environment and command
CMD="node proto_server.js"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
    # Set the environment variable for secure connection
    export GRPC_HELLO_SECURE="Y"
    echo "TLS mode enabled"

    # Set certificate path based on OS
    if [[ "$(uname)" == "Darwin" ]]; then
        export CERT_BASE_PATH="/var/hello_grpc/server_certs"
    elif [[ "$(uname)" == "Linux" ]]; then
        export CERT_BASE_PATH="/var/hello_grpc/server_certs"
    else
        export CERT_BASE_PATH="d:\\garden\\var\\hello_grpc\\server_certs"
    fi

    # Check if certificate directory exists
    if [ ! -d "$CERT_BASE_PATH" ]; then
        echo "Error: Certificate directory does not exist: $CERT_BASE_PATH"
        echo "Please create the directory and add the necessary certificate files:"
        echo "  - cert.pem: Server certificate"
        echo "  - private.key: Server private key"
        echo "  - full_chain.pem: Certificate chain"
        echo "  - myssl_root.cer: Root certificate"
        exit 1
    fi

    # Check if the required certificate files exist
    if [ ! -f "$CERT_BASE_PATH/cert.pem" ] || [ ! -f "$CERT_BASE_PATH/private.key" ] ||
        [ ! -f "$CERT_BASE_PATH/full_chain.pem" ] || [ ! -f "$CERT_BASE_PATH/myssl_root.cer" ]; then
        echo "Error: Required certificate files are missing in $CERT_BASE_PATH"
        echo "Please make sure the following files exist:"
        echo "  - cert.pem: Server certificate"
        echo "  - private.key: Server private key"
        echo "  - full_chain.pem: Certificate chain"
        echo "  - myssl_root.cer: Root certificate"
        exit 1
    fi

    echo "Using certificates from: $CERT_BASE_PATH"

    # We still pass --tls for backward compatibility
    CMD="$CMD --tls $ADDITIONAL_ARGS"
else
    [ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"
fi

# Execute the command
echo "Running: $CMD"
eval "$CMD"
