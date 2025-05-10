#!/bin/bash
# Build script for Go gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Go gRPC project..."

# Configure GOPROXY for faster downloads in some regions
export GOPROXY=https://mirrors.aliyun.com/goproxy/

# Ensure dependencies are up-to-date
echo "Updating Go modules..."
go mod tidy

# Create pb directory for generated code
mkdir -p ./common/pb

# Generate Go code from proto files
echo "Checking if protobuf files need to be generated..."
PB_FILE="./common/pb/landing.pb.go"
GRPC_FILE="./common/pb/landing_grpc.pb.go"

if [ ! -f "$PB_FILE" ] || [ ! -f "$GRPC_FILE" ] || [ ../proto/landing.proto -nt "$PB_FILE" ]; then
    echo "Generating protobuf code..."
    protoc -I ../proto \
      --go_out=./common/pb --go_opt=paths=source_relative \
      --go-grpc_out=./common/pb --go-grpc_opt=paths=source_relative \
      ../proto/landing.proto
else
    echo "Protobuf files are up to date, skipping generation"
fi

# Format source code
echo "Formatting Go code..."
go fmt ./...

# Create bin directory if it doesn't exist
mkdir -p bin

# Build binaries
echo "Building binaries..."
SERVER_BIN="./bin/server"
CLIENT_BIN="./bin/client"

# Check if binaries need to be rebuilt
SERVER_NEEDS_BUILD=true
CLIENT_NEEDS_BUILD=true

if [ -f "$SERVER_BIN" ]; then
    # Check if any server source files are newer than the binary
    if ! find ./server -name "*.go" -newer "$SERVER_BIN" | grep -q .; then
        if ! find ./common -name "*.go" -newer "$SERVER_BIN" | grep -q .; then
            SERVER_NEEDS_BUILD=false
            echo "Server binary is up to date"
        fi
    fi
fi

if [ -f "$CLIENT_BIN" ]; then
    # Check if any client source files are newer than the binary
    if ! find ./client -name "*.go" -newer "$CLIENT_BIN" | grep -q .; then
        if ! find ./common -name "*.go" -newer "$CLIENT_BIN" | grep -q .; then
            CLIENT_NEEDS_BUILD=false
            echo "Client binary is up to date"
        fi
    fi
fi

if [ "$SERVER_NEEDS_BUILD" = true ]; then
    echo "Building server..."
    go build -o "$SERVER_BIN" ./server
fi

if [ "$CLIENT_NEEDS_BUILD" = true ]; then
    echo "Building client..."
    go build -o "$CLIENT_BIN" ./client
fi

echo "Go gRPC project built successfully!"
