#!/usr/bin/env bash
# Build script for Rust gRPC project
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

log_build "Building Rust gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "cargo::curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"; then
    exit 1
fi

# Set Rust mirror if in China
if [ "$USE_CHINA_MIRROR" = "true" ]; then
    export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
    # Check if .cargo/config.toml exists
    if [ ! -f "$HOME/.cargo/config.toml" ]; then
        mkdir -p "$HOME/.cargo"
        cat > "$HOME/.cargo/config.toml" << EOF
[source.crates-io]
replace-with = 'tuna'

[source.tuna]
registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"
EOF
    fi
fi

# Clean if requested
if [ "${CLEAN_BUILD}" = true ]; then
    log_build "Cleaning previous build artifacts..."
    cargo clean
fi

# Install required dependencies if not already installed
if ! cargo install --list | grep -q "protobuf-codegen"; then
    log_build "Installing protobuf-codegen..."
    cargo install protobuf-codegen
fi

# Build mode
BUILD_MODE=""
if [ "${RELEASE_MODE}" = true ]; then
    BUILD_MODE="--release"
    log_build "Building in release mode (optimized)"
fi

# Check if we need to rebuild
NEEDS_BUILD=true
if [ "${CLEAN_BUILD}" = false ] && [ -d "target/debug" ]; then
    if ! dir_newer_than "src" "target/debug" "*.rs" && \
       ! is_newer "Cargo.toml" "target/debug" && \
       ! dir_newer_than "../proto" "target/debug" "*.proto"; then
        NEEDS_BUILD=false
        log_debug "Rust project is up to date, skipping build"
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    log_build "Building Rust project..."
    execute_build_command "cargo build ${BUILD_MODE}"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    cargo test
fi

# End build timer
end_build_timer
