#!/bin/bash
# Build script for Rust gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Rust gRPC project..."

# Check if Rust/Cargo is installed
if ! command -v cargo &> /dev/null; then
    echo "Cargo is not installed. Installing Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # Source cargo environment after installation
    source "$HOME/.cargo/env"
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

# Check if we need to clean
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    cargo clean
    shift
fi

# Install required dependencies if not already installed
if ! cargo install --list | grep -q "protobuf-codegen"; then
    echo "Installing protobuf-codegen..."
    cargo install protobuf-codegen
fi

# Check if we need to rebuild
if [ -d "target/debug" ] && [ ! "$(find src -type f -name "*.rs" -newer "target/debug" 2>/dev/null)" ] && \
   [ ! "$(find . -name "Cargo.toml" -newer "target/debug" 2>/dev/null)" ] && \
   [ ! "$(find ../proto -name "*.proto" -newer "target/debug" 2>/dev/null)" ]; then
    echo "Rust project is up to date, skipping build"
else
    echo "Building Rust project..."
    # Build in development mode
    cargo build "$@"
fi

echo "Rust gRPC project built successfully!"
