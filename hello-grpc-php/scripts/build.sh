#!/usr/bin/env bash
# Build script for PHP gRPC project
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

log_build "Building PHP gRPC project..."

# Start build timer
start_build_timer

# Check dependencies
if ! check_dependencies "php:8.0+:brew install php" "composer::https://getcomposer.org/download/"; then
    exit 1
fi

# Display PHP and Composer versions
if [ "${VERBOSE}" = true ]; then
    log_build "Using PHP version:"
    php -v
    log_build "Using Composer version:"
    composer --version
fi

# Clean if requested
if [ "${CLEAN_BUILD}" = true ]; then
    log_build "Cleaning previous build artifacts..."
    rm -f composer.lock
    rm -rf vendor
fi

# Check if dependencies need to be installed
if [ ! -d "vendor" ] || [ ! -f "composer.lock" ] || [ "composer.json" -nt "composer.lock" ]; then
    log_build "Installing PHP dependencies..."
    if [ "${VERBOSE}" = true ]; then
        composer install
    else
        composer install --quiet
    fi
else
    log_debug "PHP dependencies are up to date, skipping installation"
fi

# Check if proto generation is needed
PROTO_PATH="../proto/landing.proto"
PROTO_OUTPUT_DIR="./src/Generated"
PROTO_PHP_FILE="$PROTO_OUTPUT_DIR/Landing.php"

# Check if proto directory exists, if not create it
ensure_dir "$PROTO_OUTPUT_DIR"

# Check if proto files need to be regenerated
if proto_needs_regen "$PROTO_PATH" "$PROTO_PHP_FILE"; then
    log_build "Generating PHP protobuf code..."
    protoc --php_out="$PROTO_OUTPUT_DIR" -I../proto ../proto/landing.proto
    
    # Generate PHP gRPC stubs
    if command -v protoc-gen-php-grpc &> /dev/null; then
        protoc --php-grpc_out="$PROTO_OUTPUT_DIR" -I../proto ../proto/landing.proto
    else
        log_warning "protoc-gen-php-grpc not found. PHP gRPC stubs will not be generated."
    fi
else
    log_debug "PHP protobuf files are up to date, skipping generation"
fi

# Run tests if requested
if [ "${RUN_TESTS}" = true ]; then
    log_build "Running tests..."
    vendor/bin/phpunit
fi

# End build timer
end_build_timer
