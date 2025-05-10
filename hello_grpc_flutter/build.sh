#!/bin/bash
# Build script for Flutter gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Flutter gRPC project..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter is not installed. Please install Flutter before continuing."
    echo "Visit https://flutter.dev/docs/get-started/install for installation instructions."
    exit 1
fi

# Display Flutter version
echo "Using Flutter version:"
flutter --version

# Check if we need to clean
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    flutter clean
    shift
fi

# Check if dependencies need to be installed
if [ ! -d ".dart_tool" ] || [ "pubspec.yaml" -nt ".dart_tool" ]; then
    echo "Getting Flutter dependencies..."
    flutter pub get
else
    echo "Flutter dependencies are up to date, skipping installation"
fi

# Check if proto link script needs to be run
PROTO_SCRIPT="./proto_link.sh"
if [ -f "$PROTO_SCRIPT" ]; then
    echo "Running proto link script..."
    chmod +x "$PROTO_SCRIPT"
    "$PROTO_SCRIPT"
fi

# Check if build is needed
BUILD_DIR="build"
if [ ! -d "$BUILD_DIR" ] || [ "pubspec.yaml" -nt "$BUILD_DIR" ] || [ -n "$(find lib -name "*.dart" -newer "$BUILD_DIR" 2>/dev/null)" ]; then
    echo "Building Flutter project..."
    flutter build "$@"
else
    echo "Flutter project is up to date, skipping build"
fi

echo "Flutter gRPC project built successfully!"
