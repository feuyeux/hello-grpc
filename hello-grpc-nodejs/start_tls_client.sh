#!/bin/bash

# Start gRPC TLS Client
# This script starts the gRPC client with TLS enabled

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERT_PATH="$PROJECT_ROOT/docker/tls/client_certs"

echo "Starting gRPC TLS Client..."
echo "Certificate path: $CERT_PATH"
echo "Server: localhost:50051"
echo ""

# Set environment variables
export GRPC_HELLO_SECURE=Y
export CERT_BASE_PATH="$CERT_PATH"
export GRPC_SERVER_PORT=50051

# Start client
node "$SCRIPT_DIR/proto_client.js"
