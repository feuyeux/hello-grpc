#!/usr/bin/env bash
# Build script for Python gRPC project
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

log_build "Building Python gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "python3:3.8+:brew install python@3" "pip3::python3 -m ensurepip"; then
    exit 1
fi

# Clean if requested
standard_clean "landing_pb2.py" "landing_pb2_grpc.py" "__pycache__"

# Check for virtual environment
if [ ! -d "venv" ]; then
    log_build "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
elif [ -z "$VIRTUAL_ENV" ]; then
    log_debug "Activating virtual environment..."
    source venv/bin/activate
fi

# Check if requirements file exists
if [ -f "requirements.txt" ]; then
    log_build "Installing Python dependencies..."
    if [ "${VERBOSE}" = true ]; then
        pip install -r requirements.txt
    else
        pip install -q -r requirements.txt
    fi
else
    log_warning "requirements.txt not found. Skipping dependency installation."
fi

# Generate Python code from proto files
PROTO_PATH="../proto/landing.proto"
PB_FILE="landing_pb2.py"
GRPC_FILE="landing_pb2_grpc.py"

# Check if proto files need to be regenerated
if proto_needs_regen "$PROTO_PATH" "$PB_FILE" || [ ! -f "$GRPC_FILE" ]; then
    log_build "Generating protobuf code..."
    python3 -m grpc_tools.protoc \
      -I../proto \
      --python_out=. \
      --grpc_python_out=. \
      ../proto/landing.proto
else
    log_debug "Protobuf files are up to date, skipping generation"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    if [ -d "tests" ]; then
        python3 -m pytest tests/
    else
        log_warning "No tests directory found"
    fi
fi

# End build timer
end_build_timer
