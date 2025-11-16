#!/bin/bash

# Start gRPC TLS Server
# This script starts the gRPC server with TLS enabled

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CERT_PATH="$PROJECT_ROOT/docker/tls/server_certs"

echo "Starting gRPC TLS Server..."
echo "Certificate path: $CERT_PATH"
echo "Server port: 50051"
echo ""

# Set environment variables
export GRPC_HELLO_SECURE=Y
export CERT_BASE_PATH="$CERT_PATH"
export GRPC_SERVER_PORT=50051

# Start server
node "$SCRIPT_DIR/proto_server.js"
