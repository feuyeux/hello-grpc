#!/usr/bin/env bash
# Build script for Java gRPC project
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit

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

# Add Maven to PATH if not already there
if [ -d "/mnt/d/zoo/apache-maven-3.9.7/bin" ]; then
    export PATH="/mnt/d/zoo/apache-maven-3.9.7/bin:$PATH"
fi

log_build "Building Java gRPC project..."

# Start build timer
start_build_timer

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
    if [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    elif [ -d "/usr/lib/jvm/java-21-openjdk" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
    elif [ -d "/usr/lib/jvm/default-java" ]; then
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
    log_warning "JAVA_HOME directory does not exist: $JAVA_HOME"
    exit 1
fi

# Check for Maven (after PATH is set)
if ! command -v mvn &> /dev/null; then
    # Try to find Maven in common locations
    if [ -f "/mnt/d/zoo/apache-maven-3.9.7/bin/mvn" ]; then
        export PATH="/mnt/d/zoo/apache-maven-3.9.7/bin:$PATH"
    elif [ -f "/usr/share/maven/bin/mvn" ]; then
        export PATH="/usr/share/maven/bin:$PATH"
    else
        log_error "Maven is not installed. Please install Maven before continuing."
        exit 1
    fi
fi

# Check dependencies
if ! check_dependencies "java:17+:brew install openjdk@21" "mvn:3.8+:brew install maven"; then
    exit 1
fi

log_build "Using Java from: $JAVA_HOME"
if [ "${VERBOSE}" = true ]; then
    mvn -v
fi

# Check if server and client jars exist and if we need to rebuild
SERVER_JAR="target/hello-grpc-java-server.jar"
CLIENT_JAR="target/hello-grpc-java-client.jar"
POM_FILE="pom.xml"
SERVER_POM="server_pom.xml"
CLIENT_POM="client_pom.xml"

NEEDS_BUILD=false
if [ "$CLEAN_BUILD" = true ] || [ ! -f "$SERVER_JAR" ] || [ ! -f "$CLIENT_JAR" ] || \
   [ "$POM_FILE" -nt "$SERVER_JAR" ] || [ "$SERVER_POM" -nt "$SERVER_JAR" ] || \
   [ "$CLIENT_POM" -nt "$CLIENT_JAR" ]; then
    NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = true ]; then
    log_build "Building Java project with Maven..."
    
    # Build with clean if requested
    if [ "$CLEAN_BUILD" = true ]; then
        log_build "Cleaning previous build artifacts..."
        if [ "${RUN_TESTS}" = true ]; then
            execute_build_command "mvn clean install"
        else
            execute_build_command "mvn clean install -DskipTests"
        fi
    else
        if [ "${RUN_TESTS}" = true ]; then
            execute_build_command "mvn install"
        else
            execute_build_command "mvn install -DskipTests"
        fi
    fi
else
    log_debug "Java project is up to date, skipping build"
fi

# End build timer
end_build_timer
