#!/bin/bash
# Build script for Python gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Python gRPC project..."

# Check for virtual environment
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python -m venv venv
    source venv/bin/activate
elif [ -z "$VIRTUAL_ENV" ]; then
    source venv/bin/activate
fi

# Check if requirements file exists
if [ -f "requirements.txt" ]; then
    echo "Installing Python dependencies..."
    pip install -r requirements.txt
else
    echo "Warning: requirements.txt not found. Skipping dependency installation."
fi

# Generate Python code from proto files
PROTO_PATH="../proto/landing.proto"
PB_FILE="landing_pb2.py"
GRPC_FILE="landing_pb2_grpc.py"

# Check if proto files need to be regenerated
if [ ! -f "$PB_FILE" ] || [ ! -f "$GRPC_FILE" ] || [ "$PROTO_PATH" -nt "$PB_FILE" ]; then
    echo "Generating protobuf code..."
    python -m grpc_tools.protoc \
      -I../proto \
      --python_out=. \
      --grpc_python_out=. \
      ../proto/landing.proto
else
    echo "Protobuf files are up to date, skipping generation"
fi

echo "Python gRPC project built successfully!"
