#!/bin/bash
# Build script for Swift gRPC project
set -e

# Change to the script's directory
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "Building Swift gRPC project..."

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "Swift is not installed. Please install Swift before continuing."
    echo "Visit https://swift.org/download/ for installation instructions."
    exit 1
fi

# Display Swift version
echo "Using Swift version:"
swift --version

# Check if we need to clean
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    swift package clean
    shift
fi

# Check if dependencies need to be resolved
PACKAGE_FILE="Package.swift"
PACKAGE_RESOLVED=".build/checkouts"
if [ ! -d "$PACKAGE_RESOLVED" ] || [ "$PACKAGE_FILE" -nt "$PACKAGE_RESOLVED" ]; then
    echo "Resolving Swift package dependencies..."
    swift package resolve
else
    echo "Swift package dependencies are up to date"
fi

# Check if build is needed
BUILD_DIR=".build"
if [ ! -d "$BUILD_DIR" ] || [ "$PACKAGE_FILE" -nt "$BUILD_DIR" ] || [ -n "$(find Sources -name "*.swift" -newer "$BUILD_DIR" 2>/dev/null)" ]; then
    echo "Building Swift project..."
    swift build "$@"
else
    echo "Swift project is up to date, skipping build"
fi

echo "Swift gRPC project built successfully!"