#!/usr/bin/env bash
# Build script for Swift gRPC project
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
    RELEASE_MODE=false
    VERBOSE=false
    log_build() { echo "[BUILD] $*"; }
    log_success() { echo "[BUILD] $*"; }
    log_error() { echo "[BUILD] $*" >&2; }
    log_debug() { :; }
fi

log_build "Building Swift gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "swift:5.7+:brew install swift"; then
    exit 1
fi

# Display Swift version
if [ "${VERBOSE}" = true ]; then
    log_build "Using Swift version:"
    swift --version
fi

# Clean if requested
if [ "${CLEAN_BUILD}" = true ]; then
    log_build "Cleaning previous build artifacts..."
    swift package clean
fi

# Check if dependencies need to be resolved
PACKAGE_FILE="Package.swift"
PACKAGE_RESOLVED=".build/checkouts"
if [ ! -d "$PACKAGE_RESOLVED" ] || [ "$PACKAGE_FILE" -nt "$PACKAGE_RESOLVED" ]; then
    log_build "Resolving Swift package dependencies..."
    swift package resolve
else
    log_debug "Swift package dependencies are up to date"
fi

# Check if build is needed
BUILD_DIR=".build"
NEEDS_BUILD=true
if [ "${CLEAN_BUILD}" = false ] && [ -d "$BUILD_DIR" ]; then
    if ! is_newer "$PACKAGE_FILE" "$BUILD_DIR" && ! dir_newer_than "Sources" "$BUILD_DIR" "*.swift"; then
        NEEDS_BUILD=false
        log_debug "Swift project is up to date, skipping build"
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    log_build "Building Swift project..."
    
    # Build configuration
    BUILD_CONFIG=""
    if [ "${RELEASE_MODE}" = true ]; then
        BUILD_CONFIG="-c release"
        log_build "Building in release mode (optimized)"
    fi
    
    execute_build_command "swift build ${BUILD_CONFIG}"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    swift test
fi

# End build timer
end_build_timer
