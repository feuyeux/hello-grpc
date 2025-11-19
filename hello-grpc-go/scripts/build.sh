#!/usr/bin/env bash
# Build script for Go gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Default configuration
CLEAN_BUILD=false
RUN_TESTS=false
RELEASE_MODE=false
VERBOSE=false

# Logging functions
log_build() { echo "[BUILD] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_debug() { [ "$VERBOSE" = true ] && echo "[DEBUG] $*"; }

# Helper functions
ensure_dir() { mkdir -p "$1"; }

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean|-c)
                CLEAN_BUILD=true
                shift
                ;;
            --test|-t)
                RUN_TESTS=true
                shift
                ;;
            --release|-r)
                RELEASE_MODE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --clean, -c        Clean build artifacts before building"
                echo "  --test, -t         Run tests after building"
                echo "  --release, -r      Build in release mode (optimized)"
                echo "  --verbose, -v      Enable verbose output"
                echo "  --help, -h         Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help to see available options"
                exit 1
                ;;
        esac
    done
}

parse_arguments "$@"

log_build "Building Go gRPC project..."

# Display Go version
if [ "$VERBOSE" = true ]; then
    log_build "Go version: $(go version)"
fi

# Check if Go is installed
if ! command -v go &> /dev/null; then
    log_error "Go is not installed"
    log_error "Install with: brew install go (macOS) or visit https://golang.org/dl/"
    exit 1
fi

# Check if protoc is installed
if ! command -v protoc &> /dev/null; then
    log_error "protoc is not installed"
    log_error "Install with: brew install protobuf (macOS)"
    exit 1
fi

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    log_build "Cleaning previous build artifacts..."
    rm -rf bin/ common/pb/
fi

# Configure GOPROXY for faster downloads in some regions
export GOPROXY=https://mirrors.aliyun.com/goproxy/

# Ensure dependencies are up-to-date
log_build "Updating Go modules..."
go mod tidy

# Create pb directory for generated code
ensure_dir "./common/pb"

# Generate Go code from proto files
PB_FILE="./common/pb/landing.pb.go"
GRPC_FILE="./common/pb/landing_grpc.pb.go"
PROTO_FILE="../proto/landing.proto"

# Check if proto files need to be regenerated
NEEDS_PROTO_GEN=false
if [ "$CLEAN_BUILD" = true ] || [ ! -f "$PB_FILE" ] || [ ! -f "$GRPC_FILE" ]; then
    NEEDS_PROTO_GEN=true
elif [ "$PROTO_FILE" -nt "$PB_FILE" ] || [ "$PROTO_FILE" -nt "$GRPC_FILE" ]; then
    NEEDS_PROTO_GEN=true
fi

if [ "$NEEDS_PROTO_GEN" = true ]; then
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

if [ "$CLEAN_BUILD" = false ]; then
    if [ -f "$SERVER_BIN" ]; then
        # Check if any Go files are newer than the binary
        if [ -z "$(find ./server ./common -name "*.go" -newer "$SERVER_BIN" 2>/dev/null)" ]; then
            SERVER_NEEDS_BUILD=false
            log_debug "Server binary is up to date"
        fi
    fi
    
    if [ -f "$CLIENT_BIN" ]; then
        # Check if any Go files are newer than the binary
        if [ -z "$(find ./client ./common -name "*.go" -newer "$CLIENT_BIN" 2>/dev/null)" ]; then
            CLIENT_NEEDS_BUILD=false
            log_debug "Client binary is up to date"
        fi
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
if [ "$RUN_TESTS" = true ]; then
    log_build "Running tests..."
    go test ./...
fi

log_success "Build completed successfully!"
