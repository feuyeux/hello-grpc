#!/usr/bin/env bash
# Build script for Java gRPC project
set -e
SCRIPT_PATH="$(
    cd "$(dirname "$0")" >/dev/null 2>&1 || exit
    pwd -P
)"
cd "$SCRIPT_PATH" || exit

echo "Building Java gRPC project..."

# Set JAVA_HOME based on OS
case "$(uname -s)" in
Darwin)
    if [ -d "/Users/han/zoo/jdk-24.0.1.jdk/Contents/Home" ]; then
        export JAVA_HOME="/Users/han/zoo/jdk-24.0.1.jdk/Contents/Home"
    elif [ -d "$(/usr/libexec/java_home 2>/dev/null)" ]; then
        export JAVA_HOME="$(/usr/libexec/java_home)"
    else
        echo "JAVA_HOME not found. Please install Java or set JAVA_HOME manually."
        exit 1
    fi
    ;;
Linux)
    if [ -d "/usr/lib/jvm/default-java" ]; then
        export JAVA_HOME="/usr/lib/jvm/default-java"
    elif [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
    else
        echo "JAVA_HOME not found. Please install Java or set JAVA_HOME manually."
        exit 1
    fi
    ;;
MSYS_NT* | MINGW64_NT*)
    if [ -d "D:/zoo/jdk-24.0.1" ]; then
        export JAVA_HOME="D:/zoo/jdk-24.0.1"
    else
        echo "JAVA_HOME not found. Please install Java or set JAVA_HOME manually."
        exit 1
    fi
    ;;
*)
    echo "Unsupported OS: $(uname -s)"
    echo "Please set JAVA_HOME manually before running this script."
    exit 1
    ;;
esac

# Verify JAVA_HOME exists
if [ -n "$JAVA_HOME" ] && [ ! -d "$JAVA_HOME" ]; then
    echo "Warning: JAVA_HOME directory does not exist: $JAVA_HOME"
    exit 1
fi

# Check for Maven
if ! command -v mvn &> /dev/null; then
    echo "Maven is not installed. Please install Maven before continuing."
    exit 1
fi

echo "Using Java from: $JAVA_HOME"
mvn -v

# Check if we need to clean
CLEAN_BUILD=false
if [ "$1" == "--clean" ]; then
    CLEAN_BUILD=true
    shift
fi

# Check if server and client jars exist and if we need to rebuild
SERVER_JAR="target/hello-grpc-java-server.jar"
CLIENT_JAR="target/hello-grpc-java-client.jar"
POM_FILE="pom.xml"
SERVER_POM="server_pom.xml"
CLIENT_POM="client_pom.xml"

if [ "$CLEAN_BUILD" = true ] || [ ! -f "$SERVER_JAR" ] || [ ! -f "$CLIENT_JAR" ] || \
   [ "$POM_FILE" -nt "$SERVER_JAR" ] || [ "$SERVER_POM" -nt "$SERVER_JAR" ] || \
   [ "$CLIENT_POM" -nt "$CLIENT_JAR" ]; then
    echo "Building Java project with Maven..."
    
    # Build with clean if requested
    if [ "$CLEAN_BUILD" = true ]; then
        echo "Cleaning previous build artifacts..."
        mvn clean install -DskipTests "$@"
    else
        mvn install -DskipTests "$@"
    fi
else
    echo "Java project is up to date, skipping build"
fi

echo "Java gRPC project built successfully!"
