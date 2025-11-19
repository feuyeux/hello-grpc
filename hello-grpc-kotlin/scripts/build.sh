#!/usr/bin/env bash
# Build script for Kotlin gRPC project
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

log_build "Building Kotlin gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "java:11+:brew install openjdk@21" "gradle:9.0+:brew install gradle"; then
    exit 1
fi

# Clean if requested
if [ "${CLEAN_BUILD}" = true ]; then
    log_build "Cleaning previous build artifacts..."
    gradle clean
fi

# Check if build is needed
BUILD_GRADLE="build.gradle.kts"
SETTINGS_GRADLE="settings.gradle.kts"
BUILD_DIR="build"

NEEDS_BUILD=true
if [ "${CLEAN_BUILD}" = false ] && [ -d "$BUILD_DIR" ]; then
    # Check if gradle files have been modified
    if ! is_newer "$BUILD_GRADLE" "$BUILD_DIR" && ! is_newer "$SETTINGS_GRADLE" "$BUILD_DIR"; then
        # Check if any kotlin files have been modified
        if ! dir_newer_than "." "$BUILD_DIR" "*.kt"; then
            NEEDS_BUILD=false
            log_debug "Kotlin project is up to date, skipping build"
        fi
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    log_build "Building Kotlin project with Gradle..."
    
    # Build command
    BUILD_CMD="gradle build"
    if [ "${RUN_TESTS}" = false ]; then
        BUILD_CMD="${BUILD_CMD} -x test"
    fi
    
    execute_build_command "${BUILD_CMD}"
fi

# Run tests if requested (and not already run during build)
if [ "${RUN_TESTS}" = true ] && [ "$NEEDS_BUILD" = false ]; then
    log_build "Running tests..."
    gradle test
fi

# End build timer
end_build_timer
