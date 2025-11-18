#!/usr/bin/env bash
# Build script for Dart gRPC project
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

log_build "Building Dart gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "dart:2.17+:brew install dart"; then
    exit 1
fi

# Display Dart version
if [ "${VERBOSE}" = true ]; then
    log_build "Using Dart version:"
    dart --version
fi

# Clean if requested
standard_clean ".dart_tool/" "build/" "lib/src/generated/"

# Check if pubspec.lock exists and is older than pubspec.yaml
if [ ! -f "pubspec.lock" ] || [ "pubspec.yaml" -nt "pubspec.lock" ]; then
    log_build "Installing Dart dependencies..."
    dart pub get
else
    log_debug "Dependencies are up to date, skipping installation"
fi

# Check if proto generation is needed
PROTO_PATH="../proto/landing.proto"
PROTO_OUTPUT_DIR="./lib/src/generated"
PROTO_DART_FILE="$PROTO_OUTPUT_DIR/landing.pb.dart"
PROTO_GRPC_FILE="$PROTO_OUTPUT_DIR/landing.pbgrpc.dart"

# Check if proto directory exists, if not create it
ensure_dir "$PROTO_OUTPUT_DIR"

# Check if proto files need to be regenerated
if proto_needs_regen "$PROTO_PATH" "$PROTO_DART_FILE" || [ ! -f "$PROTO_GRPC_FILE" ]; then
    log_build "Generating Dart protobuf code..."
    
    # Make sure protoc plugin for Dart is installed
    if ! dart pub global list | grep -q "protoc_plugin"; then
        log_build "Installing protoc_plugin for Dart..."
        dart pub global activate protoc_plugin
    fi
    
    # Add Dart pub-cache bin to PATH temporarily
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    
    # Generate the Dart code from proto file
    protoc --dart_out=grpc:"$PROTO_OUTPUT_DIR" -I../proto ../proto/landing.proto
else
    log_debug "Dart protobuf files are up to date, skipping generation"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    dart test
fi

# End build timer
end_build_timer
