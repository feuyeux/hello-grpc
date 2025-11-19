#!/bin/bash
# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT" || exit

# Preparation steps
echo "Checking and installing dependencies if needed..."
if [ ! -d "node_modules" ] || [ ! -d "node_modules/@grpc" ]; then
    echo "Installing required gRPC dependencies..."
    npm install
    echo "Dependencies installed successfully"
else
    echo "Dependencies already installed"
fi

# Build TypeScript if needed
echo "Checking TypeScript build..."
if [ ! -d "dist" ] || [ ! -f "dist/hello_server.js" ]; then
    echo "Building TypeScript project..."
    npm run build
    # Copy proto-generated files to dist
    cp src/generated/landing_*.js dist/generated/ 2>/dev/null || true
    echo "Build completed successfully"
else
    echo "Build already exists"
fi

# Default configuration
USE_TLS=false
SERVER_PORT="9996"
SERVER_ADDR="0.0.0.0"
LOG_LEVEL=""

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --tls)
        USE_TLS=true
        shift
        ;;
    --addr=*)
        ADDR="${1#*=}"
        # Parse host:port
        if [[ $ADDR == *:* ]]; then
            SERVER_ADDR="${ADDR%:*}"
            SERVER_PORT="${ADDR#*:}"
        else
            SERVER_PORT="$ADDR"
        fi
        shift
        ;;
    --port=*)
        SERVER_PORT="${1#*=}"
        shift
        ;;
    --log=*)
        LOG_LEVEL="${1#*=}"
        shift
        ;;
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tls                 Enable TLS communication"
        echo "  --addr=HOST:PORT      Specify server address (default: 0.0.0.0:9996)"
        echo "  --port=PORT           Specify server port (default: 9996)"
        echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
        echo "  --help                Show this help message"
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
done

# Set server port
export GRPC_SERVER_PORT="$SERVER_PORT"

# Set log level if specified
if [ -n "$LOG_LEVEL" ]; then
    export LOG_LEVEL="$LOG_LEVEL"
fi

# Prepare environment and command
CMD="node dist/hello_server.js"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
    # Set the environment variable for secure connection
    export GRPC_HELLO_SECURE="Y"
    echo "TLS mode enabled"

    # First try to use project-local certificates
    # PROJECT_ROOT is already set at the beginning of the script
    PROJECT_CERT_PATH="$PROJECT_ROOT/../docker/tls/server_certs"
    
    if [ -d "$PROJECT_CERT_PATH" ] && [ -f "$PROJECT_CERT_PATH/myssl_root.cer" ]; then
        export CERT_BASE_PATH="$PROJECT_CERT_PATH"
        echo "Using project certificates: $CERT_BASE_PATH"
    else
        # Fall back to system certificate path based on OS
        if [[ "$(uname)" == "Darwin" ]]; then
            export CERT_BASE_PATH="/var/hello_grpc/server_certs"
        elif [[ "$(uname)" == "Linux" ]]; then
            export CERT_BASE_PATH="/var/hello_grpc/server_certs"
        else
            export CERT_BASE_PATH="d:\\garden\\var\\hello_grpc\\server_certs"
        fi
        echo "Using system certificates: $CERT_BASE_PATH"
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
else
    echo "TLS mode disabled (insecure)"
fi

# Display server configuration
echo "Server configuration:"
echo "  Address: $SERVER_ADDR:$SERVER_PORT"
echo "  TLS: $([ "$USE_TLS" = true ] && echo "Enabled" || echo "Disabled")"
[ -n "$LOG_LEVEL" ] && echo "  Log Level: $LOG_LEVEL"

# Execute the command
echo ""
echo "Starting gRPC TypeScript server..."
echo "Running: $CMD"
eval "$CMD"
