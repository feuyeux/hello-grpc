#!/bin/bash

# Build script for Android platform
set -e

echo "🤖 Building Tauri gRPC Client for Android..."

# Check if required tools are installed
check_requirements() {
    echo "📋 Checking requirements..."
    
    if ! command -v cargo &> /dev/null; then
        echo "❌ Rust/Cargo is not installed. Please install Rust first."
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        echo "❌ npm is not installed. Please install Node.js first."
        exit 1
    fi
    
    # Check for Android SDK
    if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
        echo "⚠️  Warning: ANDROID_HOME or ANDROID_SDK_ROOT not set. Make sure Android SDK is installed."
    fi
    
    echo "✅ Requirements check passed"
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Install npm dependencies
    npm install
    
    # Add Android target for Rust
    rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
    
    # Install Tauri CLI if not present
    if ! command -v cargo-tauri &> /dev/null; then
        echo "Installing Tauri CLI..."
        cargo install tauri-cli
    fi
    
    echo "✅ Dependencies installed"
}

# Build the application
build_app() {
    echo "🔨 Building application..."
    
    # Build for Android
    cd src-tauri
    
    # Generate Android project if it doesn't exist
    if [ ! -d "gen/android" ]; then
        echo "Generating Android project..."
        cargo tauri android init
    fi
    
    # Build APK
    echo "Building APK..."
    cargo tauri android build --target aarch64-linux-android
    
    cd ..
    
    echo "✅ Android build completed"
}

# Copy APK to output directory
copy_artifacts() {
    echo "📁 Copying build artifacts..."
    
    mkdir -p dist/android
    
    # Find and copy APK files
    find src-tauri/gen/android -name "*.apk" -exec cp {} dist/android/ \;
    
    if [ -f "dist/android/*.apk" ]; then
        echo "✅ APK files copied to dist/android/"
        ls -la dist/android/
    else
        echo "⚠️  No APK files found"
    fi
}

# Main execution
main() {
    echo "🚀 Starting Android build process..."
    
    check_requirements
    install_dependencies
    build_app
    copy_artifacts
    
    echo "🎉 Android build process completed!"
    echo "📱 APK files are available in the dist/android/ directory"
}

# Handle script arguments
case "${1:-}" in
    --debug)
        echo "🐛 Debug mode enabled"
        set -x
        main
        ;;
    --clean)
        echo "🧹 Cleaning previous builds..."
        rm -rf src-tauri/gen/android/app/build
        rm -rf src-tauri/target
        rm -rf dist/android
        echo "✅ Clean completed"
        main
        ;;
    --help|-h)
        echo "Usage: $0 [--debug|--clean|--help]"
        echo "  --debug: Enable debug output"
        echo "  --clean: Clean previous builds before building"
        echo "  --help:  Show this help message"
        exit 0
        ;;
    *)
        main
        ;;
esac