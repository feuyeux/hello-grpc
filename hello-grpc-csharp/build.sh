#!/usr/bin/env bash
# Build script for C# gRPC project
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

log_build "Building C# gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "dotnet:6.0+:https://dotnet.microsoft.com/download"; then
    exit 1
fi

# Display .NET version
if [ "${VERBOSE}" = true ]; then
    log_build "Using .NET version:"
    dotnet --version
fi

# Check if we need to clean
if [ "${CLEAN_BUILD}" = true ]; then
    log_build "Cleaning previous build artifacts..."
    dotnet clean HelloGrpc.sln
    # Also remove bin and obj directories
    find . -name "bin" -o -name "obj" | xargs rm -rf
fi

# Check if any project files have been modified since the last build
SOLUTION_FILE="HelloGrpc.sln"
SERVER_PROJECT="HelloServer/HelloServer.csproj"
CLIENT_PROJECT="HelloClient/HelloClient.csproj"
SERVER_BIN="HelloServer/bin/Debug/net9.0/HelloServer.dll"
CLIENT_BIN="HelloClient/bin/Debug/net9.0/HelloClient.dll"

NEEDS_BUILD=false

# Check if binaries exist
if [ "${CLEAN_BUILD}" = true ] || [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    NEEDS_BUILD=true
elif [ "$SOLUTION_FILE" -nt "$SERVER_BIN" ] || [ "$SERVER_PROJECT" -nt "$SERVER_BIN" ] || \
     [ "$SOLUTION_FILE" -nt "$CLIENT_BIN" ] || [ "$CLIENT_PROJECT" -nt "$CLIENT_BIN" ]; then
    NEEDS_BUILD=true
elif [ -n "$(find . -name "*.cs" -newer "$SERVER_BIN" -o -name "*.cs" -newer "$CLIENT_BIN" 2>/dev/null)" ]; then
    NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = true ]; then
    log_build "Building C# solution..."
    BUILD_CONFIG="Debug"
    if [ "${RELEASE_MODE}" = true ]; then
        BUILD_CONFIG="Release"
        log_build "Building in release mode"
    fi
    execute_build_command "dotnet build HelloGrpc.sln -c ${BUILD_CONFIG}"
else
    log_debug "C# project is up to date, skipping build"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    dotnet test HelloGrpc.sln
fi

# End build timer
end_build_timer
