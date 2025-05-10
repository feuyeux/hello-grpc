#!/bin/bash
# Build script for TypeScript gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building TypeScript gRPC project..."

# Check for node_modules
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ] || [ "package.json" -nt "node_modules/.package-lock.json" ]; then
    echo "Installing TypeScript dependencies..."
    # Configure npm registry if needed
    if [ "$USE_CHINA_MIRROR" = "true" ]; then
        npm config set registry https://registry.npmmirror.com
    fi
    
    npm install
else
    echo "Dependencies are up to date, skipping installation"
fi

# Check if proto generation is needed
PROTO_PATH="../proto/landing.proto"
PROTO_OUTPUT_DIR="./src/proto"
PROTO_TS_FILE="$PROTO_OUTPUT_DIR/landing.ts"

# Check if proto directory exists, if not create it
mkdir -p "$PROTO_OUTPUT_DIR"

# Check if proto files need to be regenerated
if [ ! -f "$PROTO_TS_FILE" ] || [ "$PROTO_PATH" -nt "$PROTO_TS_FILE" ]; then
    echo "Generating TypeScript protobuf code..."
    npm run generate-proto
else
    echo "TypeScript protobuf files are up to date, skipping generation"
fi

# Build TypeScript code
DIST_DIR="./dist"
if [ ! -d "$DIST_DIR" ] || [ -n "$(find ./src -name "*.ts" -newer "$DIST_DIR" 2>/dev/null)" ] || [ "tsconfig.json" -nt "$DIST_DIR" ]; then
    echo "Compiling TypeScript code..."
    npm run build
else
    echo "TypeScript compilation is up to date, skipping build"
fi

echo "TypeScript gRPC project built successfully!"
