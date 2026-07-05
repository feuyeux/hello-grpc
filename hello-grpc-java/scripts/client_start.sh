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
    if [ -d "/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home" ]; then
        export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
    elif JAVA_HOME_PATH="$(/usr/libexec/java_home 2>/dev/null)" && [ -n "$JAVA_HOME_PATH" ]; then
            export JAVA_HOME="$JAVA_HOME_PATH"
    else
        log_error "JAVA_HOME not found. Please install Java or set JAVA_HOME manually."
        exit 1
    fi
    ;;
Linux)
    if [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    elif [ -d "/usr/lib/jvm/java-21-openjdk" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
    elif [ -d "/usr/lib/jvm/default-java" ]; then
        export JAVA_HOME="/usr/lib/jvm/default-java"
    elif [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
    else
        log_error "JAVA_HOME not found. Please install Java or set JAVA_HOME manually."
        exit 1
    fi
    ;;
MSYS_NT* | MINGW64_NT*)
    if [ -d "D:/zoo/jdk-25.0.2" ]; then
        export JAVA_HOME="D:/zoo/jdk-25.0.2"
    elif [ -d "D:/zoo/jdk-25" ]; then
        export JAVA_HOME="D:/zoo/jdk-25"
    elif [ -d "C:/Program Files/Eclipse Adoptium/jdk-25.0.3.9-hotspot" ]; then
        export JAVA_HOME="C:/Program Files/Eclipse Adoptium/jdk-25.0.3.9-hotspot"
    elif [ -d "D:/zoo/jdk-24.0.1" ]; then
        export JAVA_HOME="D:/zoo/jdk-24.0.1"
    else
        log_error "JAVA_HOME not found. Please install Java or set JAVA_HOME manually."
        exit 1
    fi
    ;;
*)
    log_error "Unsupported OS: $(uname -s). Please set JAVA_HOME manually before running this script."
    exit 1
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
