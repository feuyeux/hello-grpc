#!/bin/bash
# Build script for Kotlin gRPC project
set -e

# Change to the script's directory
cd "$(dirname "$0")" || exit

echo "Building Kotlin gRPC project..."

# Check if gradle wrapper exists
if [ ! -f "./gradlew" ]; then
    echo "Gradle wrapper not found. Creating it..."
    gradle wrapper
fi

# Make gradlew executable
chmod +x ./gradlew

# Check if we need to clean
if [ "$1" == "--clean" ]; then
    echo "Cleaning previous build artifacts..."
    ./gradlew clean
    shift
fi

# Check if build is needed
BUILD_GRADLE="build.gradle.kts"
SETTINGS_GRADLE="settings.gradle.kts"
BUILD_DIR="build"

NEEDS_BUILD=true
if [ -d "$BUILD_DIR" ]; then
    # Check if gradle files have been modified
    if [ ! "$BUILD_GRADLE" -nt "$BUILD_DIR" ] && [ ! "$SETTINGS_GRADLE" -nt "$BUILD_DIR" ]; then
        # Check if any kotlin files have been modified
        if ! find . -name "*.kt" -newer "$BUILD_DIR" 2>/dev/null | grep -q .; then
            NEEDS_BUILD=false
            echo "Kotlin project is up to date, skipping build"
        fi
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    echo "Building Kotlin project with Gradle..."
    # Run the Gradle build with the rest of the arguments
    ./gradlew build "$@"
fi

echo "Kotlin gRPC project built successfully!"
