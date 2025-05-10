#!/bin/bash
# Build script for PHP gRPC project
set -e

# Change to the script's directory
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit

echo "Building PHP gRPC project..."

# Check if PHP is installed
if ! command -v php &> /dev/null; then
    echo "PHP is not installed. Please install PHP before continuing."
    echo "Visit https://www.php.net/downloads for installation instructions."
    exit 1
fi

# Check if Composer is installed
if ! command -v composer &> /dev/null; then
    echo "Composer is not installed. Please install Composer before continuing."
    echo "Visit https://getcomposer.org/download/ for installation instructions."
    exit 1
fi

# Display PHP and Composer versions
echo "Using PHP version:"
php -v
echo "Using Composer version:"
composer --version

# Check if we need to clean
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    rm -f composer.lock
    rm -rf vendor
    shift
fi

# Check if dependencies need to be installed
if [ ! -d "vendor" ] || [ ! -f "composer.lock" ] || [ "composer.json" -nt "composer.lock" ]; then
    echo "Installing PHP dependencies..."
    composer install
else
    echo "PHP dependencies are up to date, skipping installation"
fi

# Check if proto generation is needed
PROTO_PATH="../proto/landing.proto"
PROTO_OUTPUT_DIR="./src/Generated"
PROTO_PHP_FILE="$PROTO_OUTPUT_DIR/Landing.php"

# Check if proto directory exists, if not create it
mkdir -p "$PROTO_OUTPUT_DIR"

# Check if proto files need to be regenerated
if [ ! -f "$PROTO_PHP_FILE" ] || [ "$PROTO_PATH" -nt "$PROTO_PHP_FILE" ]; then
    echo "Generating PHP protobuf code..."
    protoc --php_out="$PROTO_OUTPUT_DIR" -I../proto ../proto/landing.proto
    
    # Generate PHP gRPC stubs
    if command -v protoc-gen-php-grpc &> /dev/null; then
        protoc --php-grpc_out="$PROTO_OUTPUT_DIR" -I../proto ../proto/landing.proto
    else
        echo "Warning: protoc-gen-php-grpc not found. PHP gRPC stubs will not be generated."
    fi
else
    echo "PHP protobuf files are up to date, skipping generation"
fi

echo "PHP gRPC project built successfully!"