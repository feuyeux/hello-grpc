#!/bin/bash
# Build script for Dart gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Dart gRPC project..."

# Check if Dart is installed
if ! command -v dart &> /dev/null; then
    echo "Dart is not installed. Please install Dart before continuing."
    echo "Visit https://dart.dev/get-dart for installation instructions."
    exit 1
fi

# Display Dart version
echo "Using Dart version:"
dart --version

# Check if pubspec.lock exists and is older than pubspec.yaml
if [ ! -f "pubspec.lock" ] || [ "pubspec.yaml" -nt "pubspec.lock" ]; then
    echo "Installing Dart dependencies..."
    dart pub get
else
    echo "Dependencies are up to date, skipping installation"
fi

# Check if proto generation is needed
PROTO_PATH="../proto/landing.proto"
PROTO_OUTPUT_DIR="./lib/src/generated"
PROTO_DART_FILE="$PROTO_OUTPUT_DIR/landing.pb.dart"
PROTO_GRPC_FILE="$PROTO_OUTPUT_DIR/landing.pbgrpc.dart"

# Check if proto directory exists, if not create it
mkdir -p "$PROTO_OUTPUT_DIR"

# Check if proto files need to be regenerated
if [ ! -f "$PROTO_DART_FILE" ] || [ ! -f "$PROTO_GRPC_FILE" ] || [ "$PROTO_PATH" -nt "$PROTO_DART_FILE" ]; then
    echo "Generating Dart protobuf code..."
    
    # Make sure protoc plugin for Dart is installed
    if ! dart pub global list | grep -q "protoc_plugin"; then
        echo "Installing protoc_plugin for Dart..."
        dart pub global activate protoc_plugin
    fi
    
    # Add Dart pub-cache bin to PATH temporarily
    export PATH="$PATH":"$HOME/.pub-cache/bin"
    
    # Generate the Dart code from proto file
    protoc --dart_out=grpc:"$PROTO_OUTPUT_DIR" -I../proto ../proto/landing.proto
else
    echo "Dart protobuf files are up to date, skipping generation"
fi

echo "Dart gRPC project built successfully!"
