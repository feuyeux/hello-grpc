#!/usr/bin/env bash
# Build script for TypeScript gRPC project
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

log_build "Building TypeScript gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "node:16+:brew install node" "npm:8+:installed with node" "tsc::npm install -g typescript"; then
    exit 1
fi

# Clean if requested
standard_clean "node_modules/" "dist/" "src/proto/"

# Check for node_modules
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ] || [ "package.json" -nt "node_modules/.package-lock.json" ]; then
    log_build "Installing TypeScript dependencies..."
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

# Check if proto generation is needed
PROTO_PATH="../proto/landing.proto"
PROTO_OUTPUT_DIR="./src/proto"
PROTO_TS_FILE="$PROTO_OUTPUT_DIR/landing.ts"

# Check if proto directory exists, if not create it
ensure_dir "$PROTO_OUTPUT_DIR"

# Check if proto files need to be regenerated
if proto_needs_regen "$PROTO_PATH" "$PROTO_TS_FILE"; then
    log_build "Generating TypeScript protobuf code..."
    npm run generate-proto
else
    log_debug "TypeScript protobuf files are up to date, skipping generation"
fi

# Build TypeScript code
DIST_DIR="./dist"
if [ "${CLEAN_BUILD}" = true ] || [ ! -d "$DIST_DIR" ] || dir_newer_than "./src" "$DIST_DIR" "*.ts" || is_newer "tsconfig.json" "$DIST_DIR"; then
    log_build "Compiling TypeScript code..."
    if [ "${VERBOSE}" = true ]; then
        npm run build
    else
        npm run build --silent
    fi
else
    log_debug "TypeScript compilation is up to date, skipping build"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    npm test
fi

# End build timer
end_build_timer
