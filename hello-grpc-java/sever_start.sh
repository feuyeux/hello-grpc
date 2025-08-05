#!/usr/bin/env bash
set -e
SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1 || exit
    pwd -P
)"
cd "$SCRIPT_PATH" || exit
sh build.sh
# Set JAVA_HOME based on OS
case "$(uname -s)" in
Darwin)
    export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
    ;;
Linux)
    echo "Linux"
    # TODO: Set Linux JAVA_HOME here
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
ADDITIONAL_ARGS=""

# Process command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    --tls)
        USE_TLS=true
        shift
        ;;
    --addr=*)
        ADDR="${1#*=}"
        ADDITIONAL_ARGS="$ADDITIONAL_ARGS -Dexec.args=\"--addr=$ADDR\""
        shift
        ;;
    --log=*)
        LOG_LEVEL="${1#*=}"
        ADDITIONAL_ARGS="$ADDITIONAL_ARGS -Dexec.args=\"--log=$LOG_LEVEL\""
        shift
        ;;
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --tls                 Enable TLS communication"
        echo "  --addr=HOST:PORT      Specify server address (default: 127.0.0.1:9996)"
        echo "  --log=LEVEL           Set log level (trace, debug, info, warn, error)"
        echo "  --help                Show this help message"
        exit 0
        ;;
    *)
        # Pass through any other arguments
        ADDITIONAL_ARGS="$ADDITIONAL_ARGS -Dexec.args=\"$1\""
        shift
        ;;
    esac
done

# Build the command
CMD="mvn exec:java -Dexec.mainClass=\"org.feuyeux.grpc.server.ProtoServer\""

# Set the TLS environment variable if enabled instead of passing flag
if [ "$USE_TLS" = true ]; then
    export GRPC_HELLO_SECURE=Y
    echo "TLS enabled via GRPC_HELLO_SECURE=Y"
fi

# Add additional arguments if any
[ -n "$ADDITIONAL_ARGS" ] && CMD="$CMD $ADDITIONAL_ARGS"

# Execute the command
echo "Running: $CMD"
eval "$CMD"
