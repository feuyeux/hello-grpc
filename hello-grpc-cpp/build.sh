#!/usr/bin/env bash
# Build script for C++ gRPC project
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

log_build "Building C++ gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "bazel::brew install bazel" "g++::xcode-select --install"; then
    exit 1
fi

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
log_build "Building with $CORES cores..."

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
    --conlyopt="-std=c11" \
    --build_tag_filters="-no_cpp" \
    --features=-supports_dynamic_linker \
    --output_filter='^((?!grpc_.*_plugin).)*$' \
    --noincompatible_sandbox_hermetic_tmp \
    --incompatible_enable_cc_toolchain_resolution=false \
    --sandbox_debug \
    --action_env=BAZEL_DO_NOT_DETECT_CPP_TOOLCHAIN=1 \
    --define=grpc_build_grpc_csharp_plugin=false \
    --define=grpc_build_grpc_node_plugin=false \
    --define=grpc_build_grpc_objective_c_plugin=false \
    --define=grpc_build_grpc_php_plugin=false \
    --define=grpc_build_grpc_python_plugin=false \
    --define=grpc_build_grpc_ruby_plugin=false \
    --extra_toolchains=@local_config_cc//:cc-toolchain-arm64-linux \
    --host_platform=@local_config_platform//:host \
    //:hello_server //:hello_client

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    bazel test //tests:hello_test
fi

# End build timer
end_build_timer