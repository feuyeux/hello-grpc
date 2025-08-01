#!/bin/bash

# Build script for iOS platform
set -e

echo "🍎 Building Tauri gRPC Client for iOS..."

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
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "❌ iOS builds require macOS. Current OS: $OSTYPE"
        exit 1
    fi
    
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ Xcode is not installed. Please install Xcode from the App Store."
        exit 1
    fi
    
    echo "✅ Requirements check passed"
}

# Install dependencies
install_dependencies() {
    echo "📦 Installing dependencies..."
    
    # Install npm dependencies
    npm install
    
    # Add iOS targets for Rust
    rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim
    
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
    
    # Build for iOS
    cd src-tauri
    
    # Generate iOS project if it doesn't exist
    if [ ! -d "gen/ios" ]; then
        echo "Generating iOS project..."
        cargo tauri ios init
    fi
    
    # Build for iOS device (release mode)
    echo "Building for iOS device..."
    cargo tauri ios build --target aarch64-apple-ios
    
    # Build for iOS simulator (debug mode)
    echo "Building for iOS simulator..."
    cargo tauri ios build --target aarch64-apple-ios-sim
    
    cd ..
    
    echo "✅ iOS build completed"
}

# Copy IPA to output directory
copy_artifacts() {
    echo "📁 Copying build artifacts..."
    
    mkdir -p dist/ios
    
    # Find and copy IPA files
    find src-tauri/gen/ios -name "*.ipa" -exec cp {} dist/ios/ \;
    
    # Find and copy app bundles
    find src-tauri/gen/ios -name "*.app" -exec cp -r {} dist/ios/ \;
    
    if ls dist/ios/*.ipa 1> /dev/null 2>&1; then
        echo "✅ IPA files copied to dist/ios/"
        ls -la dist/ios/
    else
        echo "⚠️  No IPA files found, but app bundles may be available"
        ls -la dist/ios/
    fi
}

# Open Xcode project for manual building/signing
open_xcode() {
    echo "🔧 Opening Xcode project..."
    
    if [ -d "src-tauri/gen/ios" ]; then
        # Find the Xcode project file
        XCODE_PROJECT=$(find src-tauri/gen/ios -name "*.xcodeproj" | head -n 1)
        if [ -n "$XCODE_PROJECT" ]; then
            echo "Opening $XCODE_PROJECT in Xcode..."
            open "$XCODE_PROJECT"
        else
            echo "⚠️  No Xcode project found"
        fi
    fi
}

# Main execution
main() {
    echo "🚀 Starting iOS build process..."
    
    check_requirements
    install_dependencies
    build_app
    copy_artifacts
    
    echo "🎉 iOS build process completed!"
    echo "📱 iOS artifacts are available in the dist/ios/ directory"
    echo "💡 For App Store distribution, you may need to sign the app in Xcode"
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
        rm -rf src-tauri/gen/ios/build
        rm -rf src-tauri/target
        rm -rf dist/ios
        echo "✅ Clean completed"
        main
        ;;
    --xcode)
        echo "🔧 Opening Xcode for manual build/signing..."
        check_requirements
        install_dependencies
        open_xcode
        ;;
    --help|-h)
        echo "Usage: $0 [--debug|--clean|--xcode|--help]"
        echo "  --debug: Enable debug output"
        echo "  --clean: Clean previous builds before building"
        echo "  --xcode: Open Xcode project for manual building"
        echo "  --help:  Show this help message"
        exit 0
        ;;
    *)
        main
        ;;
esac