#!/usr/bin/env bash
# Build script for Java gRPC project
set -e

# Change to the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}" || exit

# Default configuration
CLEAN_BUILD=false
RUN_TESTS=false
RELEASE_MODE=false
VERBOSE=false

# Logging functions
log_build() { echo "[BUILD] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }
log_debug() { [ "$VERBOSE" = true ] && echo "[DEBUG] $*"; }

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean|-c)
                CLEAN_BUILD=true
                shift
                ;;
            --test|-t)
                RUN_TESTS=true
                shift
                ;;
            --release|-r)
                RELEASE_MODE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [options]"
                echo "Options:"
                echo "  --clean, -c        Clean build artifacts before building"
                echo "  --test, -t         Run tests after building"
                echo "  --release, -r      Build in release mode (optimized)"
                echo "  --verbose, -v      Enable verbose output"
                echo "  --help, -h         Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help to see available options"
                exit 1
                ;;
        esac
    done
}

parse_arguments "$@"

log_build "Building Java gRPC project..."

# Add Maven to PATH if not already there
if [ -d "/mnt/d/zoo/apache-maven-3.9.7/bin" ]; then
    export PATH="/mnt/d/zoo/apache-maven-3.9.7/bin:$PATH"
fi

# Set JAVA_HOME based on OS
case "$(uname -s)" in
Darwin)
    if [ -d "/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home" ]; then
        export JAVA_HOME="/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home"
    elif JAVA_HOME_PATH="$(/usr/libexec/java_home 2>/dev/null)" && [ -n "$JAVA_HOME_PATH" ]; then
            export JAVA_HOME="$JAVA_HOME_PATH"
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
    log_error "JAVA_HOME directory does not exist: $JAVA_HOME"
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

# Display versions
if [ "$VERBOSE" = true ]; then
    log_build "Java version: $(java -version 2>&1 | head -1)"
    log_build "Maven version: $(mvn -v | head -1)"
else
    log_build "Using Java from: $JAVA_HOME"
fi

# Check if server and client jars exist and if we need to rebuild
SERVER_JAR="target/hello-grpc-java-server.jar"
CLIENT_JAR="target/hello-grpc-java-client.jar"
POM_FILE="pom.xml"
SERVER_POM="server_pom.xml"
CLIENT_POM="client_pom.xml"

NEEDS_BUILD=false
if [ "$CLEAN_BUILD" = true ] || [ ! -f "$SERVER_JAR" ] || [ ! -f "$CLIENT_JAR" ]; then
    NEEDS_BUILD=true
elif [ "$POM_FILE" -nt "$SERVER_JAR" ] || [ "$SERVER_POM" -nt "$SERVER_JAR" ] || \
     [ "$CLIENT_POM" -nt "$CLIENT_JAR" ]; then
    NEEDS_BUILD=true
elif [ -n "$(find src -name "*.java" -newer "$SERVER_JAR" 2>/dev/null)" ]; then
    NEEDS_BUILD=true
fi

if [ "$NEEDS_BUILD" = true ]; then
    log_build "Building Java project with Maven..."
    
    # Build command
    MVN_ARGS="install"
    if [ "$RUN_TESTS" = false ]; then
        MVN_ARGS="$MVN_ARGS -DskipTests"
    fi
    
    # Build with clean if requested
    if [ "$CLEAN_BUILD" = true ]; then
        log_build "Cleaning previous build artifacts..."
        MVN_ARGS="clean $MVN_ARGS"
    fi
    
    if [ "$VERBOSE" = true ]; then
        mvn $MVN_ARGS
    else
        mvn $MVN_ARGS -q
    fi
else
    log_debug "Java project is up to date, skipping build"
fi

# Run tests if requested (and not already run during build)
if [ "$RUN_TESTS" = true ] && [ "$NEEDS_BUILD" = false ]; then
    log_build "Running tests..."
    mvn test
fi

log_success "Build completed successfully!"
