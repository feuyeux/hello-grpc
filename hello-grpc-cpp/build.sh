#!/bin/bash
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

# Check if bazel is installed
if ! command -v bazel &> /dev/null; then
    echo "Bazel is not installed. Installing now..."
    brew install bazel
fi

# Clean previous build files if requested
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build files..."
    bazel clean --expunge
fi

# Determine number of CPU cores for parallel build
if command -v sysctl &> /dev/null; then
    CORES=$(sysctl -n hw.logicalcpu)
elif command -v nproc &> /dev/null; then
    CORES=$(nproc --all)
else
    CORES=4
fi
echo "Building with $CORES cores..."

# Build hello_grpc targets with all necessary flags
echo "Building server and client (C++ only)..."
bazel build \
    --jobs=$CORES \
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