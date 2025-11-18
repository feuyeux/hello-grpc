#!/usr/bin/env bash
# Build script for Go gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}" || exit

CLEAN_BUILD=false
RUN_TESTS=false
RELEASE_MODE=false
log_build() { echo "[BUILD] $*"; }
log_success() { echo "[BUILD] $*"; }
log_error() { echo "[BUILD] $*" >&2; }
log_debug() { :; }
check_dependencies() { return 0; }
start_build_timer() { :; }
end_build_timer() { :; }
standard_clean() { :; }
ensure_dir() { mkdir -p "$1"; }
proto_needs_regen() { return 0; }
dir_newer_than() { return 0; }

log_build "Building Go($(go version)) gRPC project..."

# Check dependencies
if ! check_dependencies "go:1.21+:brew install go" "protoc::brew install protobuf"; then
    exit 1
fi

# Start build timer
start_build_timer

# Clean if requested
standard_clean "bin/" "common/pb/"

# Configure GOPROXY for faster downloads in some regions
export GOPROXY=https://mirrors.aliyun.com/goproxy/

# Ensure dependencies are up-to-date
log_build "Updating Go modules..."
go mod tidy

# Create pb directory for generated code
ensure_dir "./common/pb"

# Generate Go code from proto files
log_build "Checking if protobuf files need to be generated..."
PB_FILE="./common/pb/landing.pb.go"
GRPC_FILE="./common/pb/landing_grpc.pb.go"

if proto_needs_regen "../proto/landing.proto" "$PB_FILE" || [ ! -f "$GRPC_FILE" ]; then
    log_build "Generating protobuf code..."
    protoc -I ../proto \
      --go_out=./common/pb --go_opt=paths=source_relative \
      --go-grpc_out=./common/pb --go-grpc_opt=paths=source_relative \
      ../proto/landing.proto
else
    log_debug "Protobuf files are up to date, skipping generation"
fi

# Format source code
log_build "Formatting Go code..."
go fmt ./...

# Create bin directory if it doesn't exist
ensure_dir "bin"

# Build binaries
log_build "Building binaries..."
SERVER_BIN="./bin/server"
CLIENT_BIN="./bin/client"

# Build flags
BUILD_FLAGS=""
if [ "${RELEASE_MODE}" = true ]; then
    BUILD_FLAGS="-ldflags='-s -w'"
    log_build "Building in release mode (optimized)"
fi

# Check if binaries need to be rebuilt
SERVER_NEEDS_BUILD=true
CLIENT_NEEDS_BUILD=true

if [ "${CLEAN_BUILD}" = false ]; then
    if ! dir_newer_than "./server" "$SERVER_BIN" "*.go" && ! dir_newer_than "./common" "$SERVER_BIN" "*.go"; then
        SERVER_NEEDS_BUILD=false
        log_debug "Server binary is up to date"
    fi
    
    if ! dir_newer_than "./client" "$CLIENT_BIN" "*.go" && ! dir_newer_than "./common" "$CLIENT_BIN" "*.go"; then
        CLIENT_NEEDS_BUILD=false
        log_debug "Client binary is up to date"
    fi
fi

if [ "$SERVER_NEEDS_BUILD" = true ]; then
    log_build "Building server..."
    eval "go build ${BUILD_FLAGS} -o \"$SERVER_BIN\" ./server"
fi

if [ "$CLIENT_NEEDS_BUILD" = true ]; then
    log_build "Building client..."
    eval "go build ${BUILD_FLAGS} -o \"$CLIENT_BIN\" ./client"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    go test ./...
fi

# End build timer
end_build_timer
