#!/usr/bin/env bash
# Client start script for Java gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Logging functions
log_info() { echo "[CLIENT] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

# Add Maven to PATH if not already there
if [ -d "/mnt/d/zoo/apache-maven-3.9.7/bin" ]; then
    export PATH="/mnt/d/zoo/apache-maven-3.9.7/bin:$PATH"
fi

# Build the project first
log_info "Building project..."
bash scripts/build.sh
# Set JAVA_HOME based on OS
case "$(uname -s)" in
Darwin)
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
    ;;
Linux)
    export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    ;;
MSYS_NT* | MINGW64_NT*)
    export JAVA_HOME="D:/zoo/jdk-24.0.1"
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    ;;
esac

# Default configuration
USE_TLS=false
EXEC_ARGS=""

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --tls)
        USE_TLS=true
        shift
        ;;
    --addr=*)
        ADDR="${1#*=}"
        EXEC_ARGS="$EXEC_ARGS --addr=$ADDR"
        shift
        ;;
    --log=*)
        LOG_LEVEL="${1#*=}"
        EXEC_ARGS="$EXEC_ARGS --log=$LOG_LEVEL"
        shift
        ;;
    --count=*)
        COUNT="${1#*=}"
        EXEC_ARGS="$EXEC_ARGS --count=$COUNT"
        shift
        ;;
    --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tls                 Enable TLS communication"
        echo "  --addr=HOST:PORT      Server address to connect to (default: 127.0.0.1:9996)"
        echo "  --log=LEVEL           Set log level (trace|debug|info|warn|error)"
        echo "  --count=NUMBER        Number of requests to send"
        echo "  --help, -h            Show this help message"
        exit 0
        ;;
    *)
        log_error "Unknown option: $1"
        echo "Use --help to see available options"
        exit 1
        ;;
    esac
done

log_info "Starting Java gRPC client..."

# Set environment variable for TLS if enabled
if [ "$USE_TLS" = true ]; then
    export GRPC_HELLO_SECURE=Y
    log_info "TLS enabled"
fi

# Build the command
CMD="mvn exec:java -Dexec.mainClass=\"org.feuyeux.grpc.client.ProtoClient\""

# Add exec args if any
if [ -n "$EXEC_ARGS" ]; then
    CMD="$CMD -Dexec.args=\"$EXEC_ARGS\""
fi

# Execute the command
log_info "Running: $CMD"
eval "$CMD"
