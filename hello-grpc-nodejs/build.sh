#!/usr/bin/env bash
# Build script for Node.js gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}" || exit

# Source common build functions
if [ -f "../scripts/build/build-common.sh" ]; then
    # shellcheck source=../scripts/build/build-common.sh
    source "../scripts/build/build-common.sh"
    parse_build_params "$@"
else
    echo "Warning: build-common.sh not found, using legacy mode"
    CLEAN_BUILD=false
    RUN_TESTS=false
    VERBOSE=false
    log_build() { echo "[BUILD] $*"; }
    log_success() { echo "[BUILD] $*"; }
    log_error() { echo "[BUILD] $*" >&2; }
    log_debug() { :; }
fi

log_build "Building Node.js gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "node:16+:brew install node" "npm:8+:installed with node"; then
    exit 1
fi

# Clean if requested
standard_clean "node_modules/" "src/proto/"

# Check for node_modules
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ] || [ "package.json" -nt "node_modules/.package-lock.json" ]; then
    log_build "Installing Node.js dependencies..."
    # Configure npm registry if needed
    if [ "$USE_CHINA_MIRROR" = "true" ]; then
        npm config set registry https://registry.npmmirror.com
    fi
    
    if [ "${VERBOSE}" = true ]; then
        npm install
    else
        npm install --silent
    fi
else
    log_debug "Dependencies are up to date, skipping installation"
fi

# Create proto output directory
PROTO_DIR="./src/proto"
ensure_dir "$PROTO_DIR"

# Generate JavaScript code from proto files
PROTO_PATH="../proto/landing.proto"
PB_FILE="$PROTO_DIR/landing_pb.js"
GRPC_FILE="$PROTO_DIR/landing_grpc_pb.js"

# Check if proto files need to be regenerated
if proto_needs_regen "$PROTO_PATH" "$PB_FILE" || [ ! -f "$GRPC_FILE" ]; then
    log_build "Generating protobuf code..."
    
    # Use npx to ensure we're using the local installation of grpc_tools_node_protoc
    npx grpc_tools_node_protoc \
      --js_out=import_style=commonjs,binary:"$PROTO_DIR" \
      --grpc_out=grpc_js:"$PROTO_DIR" \
      --proto_path=../proto ../proto/landing.proto
    
    # Touch the generated files to update timestamps
    touch "$PB_FILE" "$GRPC_FILE"
else
    log_debug "Protobuf files are up to date, skipping generation"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    npm test
fi

# End build timer
end_build_timer
