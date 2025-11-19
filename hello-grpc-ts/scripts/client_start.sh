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
if [ ! -d "dist" ] || [ ! -f "dist/hello_client.js" ]; then
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
SERVER_HOST="localhost"
SERVER_PORT="9996"
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
            SERVER_HOST="${ADDR%:*}"
            SERVER_PORT="${ADDR#*:}"
        else
            SERVER_HOST="$ADDR"
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
    --count=*)
        # Note: TypeScript client doesn't currently support count parameter
        # but we accept it for compatibility
        echo "Note: --count parameter is not yet implemented in TypeScript client"
        shift
        ;;
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tls                 Enable TLS communication"
        echo "  --addr=HOST:PORT      Specify server address to connect to (default: localhost:9996)"
        echo "  --port=PORT           Specify server port (default: 9996)"
        echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
        echo "  --count=NUMBER        Number of iterations (not yet implemented)"
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

# Set server connection parameters
export GRPC_SERVER="$SERVER_HOST"
export GRPC_SERVER_PORT="$SERVER_PORT"

# Set log level if specified
if [ -n "$LOG_LEVEL" ]; then
    export LOG_LEVEL="$LOG_LEVEL"
fi

# Prepare environment and command
CMD="node dist/hello_client.js"

# Add TLS flag if enabled
if [ "$USE_TLS" = true ]; then
    # Set the environment variable for secure connection
    export GRPC_HELLO_SECURE="Y"
    echo "TLS mode enabled"

    # First try to use project-local certificates
    # PROJECT_ROOT is already set at the beginning of the script
    PROJECT_CERT_PATH="$PROJECT_ROOT/../docker/tls/client_certs"
    
    if [ -d "$PROJECT_CERT_PATH" ] && [ -f "$PROJECT_CERT_PATH/myssl_root.cer" ]; then
        export CERT_BASE_PATH="$PROJECT_CERT_PATH"
        echo "Using project certificates: $CERT_BASE_PATH"
    else
        # Fall back to system certificate path based on OS
        if [[ "$(uname)" == "Darwin" ]]; then
            export CERT_BASE_PATH="/var/hello_grpc/client_certs"
        elif [[ "$(uname)" == "Linux" ]]; then
            export CERT_BASE_PATH="/var/hello_grpc/client_certs"
        else
            export CERT_BASE_PATH="d:\\garden\\var\\hello_grpc\\client_certs"
        fi
        echo "Using system certificates: $CERT_BASE_PATH"
    fi

    # Check if certificate directory exists
    if [ ! -d "$CERT_BASE_PATH" ]; then
        echo "Error: Certificate directory does not exist: $CERT_BASE_PATH"
        echo "Please create the directory and add the necessary certificate files:"
        echo "  - cert.pem: Client certificate"
        echo "  - private.key: Client private key"
        echo "  - full_chain.pem: Certificate chain"
        echo "  - myssl_root.cer: Root certificate"
        exit 1
    fi

    # Check if the root certificate file exists (minimum required for client)
    if [ ! -f "$CERT_BASE_PATH/myssl_root.cer" ]; then
        echo "Error: Root certificate file is missing in $CERT_BASE_PATH"
        echo "Please ensure myssl_root.cer exists in the certificate directory."
        exit 1
    fi

    echo "Using certificates from: $CERT_BASE_PATH"
else
    echo "TLS mode disabled (insecure)"
fi

# Display client configuration
echo "Client configuration:"
echo "  Server: $SERVER_HOST:$SERVER_PORT"
echo "  TLS: $([ "$USE_TLS" = true ] && echo "Enabled" || echo "Disabled")"
[ -n "$LOG_LEVEL" ] && echo "  Log Level: $LOG_LEVEL"

# Execute the command
echo ""
echo "Starting gRPC TypeScript client..."
echo "Running: $CMD"
eval "$CMD"
