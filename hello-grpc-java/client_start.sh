#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1 || exit
    pwd -P
)"
cd "$SCRIPT_PATH" || exit

# Add Maven to PATH if not already there
if [ -d "/mnt/d/zoo/apache-maven-3.9.7/bin" ]; then
    export PATH="/mnt/d/zoo/apache-maven-3.9.7/bin:$PATH"
fi

sh build.sh
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
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tls                 Enable TLS communication"
        echo "  --addr=HOST:PORT      Specify server address to connect to (default: 127.0.0.1:9996)"
        echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
        echo "  --count=NUMBER        Number of requests to send"
        echo "  --help                Show this help message"
        exit 0
        ;;
    *)
        # Pass through any other arguments
        EXEC_ARGS="$EXEC_ARGS $1"
        shift
        ;;
    esac
done

# Set environment variable for TLS if enabled
if [ "$USE_TLS" = true ]; then
    export GRPC_HELLO_SECURE=Y
    echo "TLS enabled: GRPC_HELLO_SECURE=Y"
fi

# Build the command
CMD="mvn exec:java -Dexec.mainClass=\"org.feuyeux.grpc.client.ProtoClient\""

# Add exec args if any (for other parameters like --addr, --log, etc.)
if [ -n "$EXEC_ARGS" ]; then
    CMD="$CMD -Dexec.args=\"$EXEC_ARGS\""
fi

# Execute the command
echo "Running: $CMD"
eval "$CMD"
