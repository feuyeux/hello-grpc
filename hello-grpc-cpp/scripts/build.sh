#!/usr/bin/env bash
# Build script for C++ gRPC project
set -e

# Change to the project root directory
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

# Get CPU cores
get_cpu_cores() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

log_build "Building C++ gRPC project..."

# Check if bazel is installed
if ! command -v bazel &> /dev/null; then
    log_error "Bazel is not installed"
    log_error "Install with: brew install bazel"
    exit 1
fi

# Clean previous build files if requested
if [ "${CLEAN_BUILD}" = true ]; then
    log_build "Cleaning previous build files..."
    bazel clean --expunge
fi

# Determine number of CPU cores for parallel build
CORES=$(get_cpu_cores)
log_build "Detected $CORES CPU cores, using parallel build..."

# Build flags
BUILD_MODE=""
if [ "${RELEASE_MODE}" = true ]; then
    BUILD_MODE="-c opt"
    log_build "Building in release mode (optimized)"
fi

# Build hello_grpc targets with all necessary flags
log_build "Building server and client..."
bazel build \
    --jobs=$CORES \
    ${BUILD_MODE} \
    --cxxopt="-std=c++17" \
    --host_cxxopt="-std=c++17" \
    --define=grpc_build_grpc_csharp_plugin=false \
    --define=grpc_build_grpc_node_plugin=false \
    --define=grpc_build_grpc_objective_c_plugin=false \
    --define=grpc_build_grpc_php_plugin=false \
    --define=grpc_build_grpc_python_plugin=false \
    --define=grpc_build_grpc_ruby_plugin=false \
    //:hello_server //:hello_client

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    bazel test //tests:hello_test
fi

log_success "Build completed successfully!"
