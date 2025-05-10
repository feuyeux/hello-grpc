#!/bin/bash
# Build script for Node.js gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Node.js gRPC project..."

# Check for node_modules
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ] || [ "package.json" -nt "node_modules/.package-lock.json" ]; then
    echo "Installing Node.js dependencies..."
    # Configure npm registry if needed
    if [ "$USE_CHINA_MIRROR" = "true" ]; then
        npm config set registry https://registry.npmmirror.com
    fi
    
    npm install
else
    echo "Dependencies are up to date, skipping installation"
fi

# Create proto output directory
PROTO_DIR="./src/proto"
mkdir -p "$PROTO_DIR"

# Generate JavaScript code from proto files
PROTO_PATH="../proto/landing.proto"
PB_FILE="$PROTO_DIR/landing_pb.js"
GRPC_FILE="$PROTO_DIR/landing_grpc_pb.js"

# Check if proto files need to be regenerated
if [ ! -f "$PB_FILE" ] || [ ! -f "$GRPC_FILE" ] || [ "$PROTO_PATH" -nt "$PB_FILE" ]; then
    echo "Generating protobuf code..."
    
    # Use npx to ensure we're using the local installation of grpc_tools_node_protoc
    npx grpc_tools_node_protoc \
      --js_out=import_style=commonjs,binary:"$PROTO_DIR" \
      --grpc_out=grpc_js:"$PROTO_DIR" \
      --proto_path=../proto ../proto/landing.proto
    
    # Touch the generated files to update timestamps
    touch "$PB_FILE" "$GRPC_FILE"
else
    echo "Protobuf files are up to date, skipping generation"
fi

echo "Node.js gRPC project built successfully!"
