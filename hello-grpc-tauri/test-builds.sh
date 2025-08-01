#!/bin/bash

# Test script for mobile platform builds
set -e

echo "🧪 Testing mobile platform build configurations..."

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test Android configuration
test_android_config() {
    echo "📱 Testing Android configuration..."
    
    # Check if Android files exist
    if [ -f "src-tauri/gen/android/app/src/main/AndroidManifest.xml" ]; then
        echo "✅ AndroidManifest.xml exists"
        
        # Validate XML syntax
        if command_exists xmllint; then
            xmllint --noout src-tauri/gen/android/app/src/main/AndroidManifest.xml 2>/dev/null && echo "✅ AndroidManifest.xml is valid XML"
        fi
        
        # Check for required permissions
        if grep -q "android.permission.INTERNET" src-tauri/gen/android/app/src/main/AndroidManifest.xml; then
            echo "✅ INTERNET permission found"
        else
            echo "❌ INTERNET permission missing"
        fi
        
        # Check for network security config
        if grep -q "networkSecurityConfig" src-tauri/gen/android/app/src/main/AndroidManifest.xml; then
            echo "✅ Network security config referenced"
        else
            echo "❌ Network security config missing"
        fi
    else
        echo "❌ AndroidManifest.xml not found"
    fi
    
    # Check network security config
    if [ -f "src-tauri/gen/android/app/src/main/res/xml/network_security_config.xml" ]; then
        echo "✅ Network security config exists"
        
        if command_exists xmllint; then
            xmllint --noout src-tauri/gen/android/app/src/main/res/xml/network_security_config.xml 2>/dev/null && echo "✅ Network security config is valid XML"
        fi
    else
        echo "❌ Network security config not found"
    fi
    
    echo ""
}

# Test iOS configuration
test_ios_config() {
    echo "🍎 Testing iOS configuration..."
    
    # Check if iOS files exist
    if [ -f "src-tauri/gen/ios/Info.plist" ]; then
        echo "✅ Info.plist exists"
        
        # Validate plist syntax (on macOS)
        if [[ "$OSTYPE" == "darwin"* ]] && command_exists plutil; then
            plutil -lint src-tauri/gen/ios/Info.plist >/dev/null 2>&1 && echo "✅ Info.plist is valid"
        fi
        
        # Check for App Transport Security
        if grep -q "NSAppTransportSecurity" src-tauri/gen/ios/Info.plist; then
            echo "✅ App Transport Security configuration found"
        else
            echo "❌ App Transport Security configuration missing"
        fi
        
        # Check for network usage description
        if grep -q "NSNetworkUsageDescription" src-tauri/gen/ios/Info.plist; then
            echo "✅ Network usage description found"
        else
            echo "❌ Network usage description missing"
        fi
    else
        echo "❌ Info.plist not found"
    fi
    
    echo ""
}

# Test build scripts
test_build_scripts() {
    echo "🔨 Testing build scripts..."
    
    # Check Android build script
    if [ -f "build-android.sh" ] && [ -x "build-android.sh" ]; then
        echo "✅ Android build script exists and is executable"
        
        # Test help option
        if ./build-android.sh --help >/dev/null 2>&1; then
            echo "✅ Android build script help works"
        fi
    else
        echo "❌ Android build script missing or not executable"
    fi
    
    # Check iOS build script
    if [ -f "build-ios.sh" ] && [ -x "build-ios.sh" ]; then
        echo "✅ iOS build script exists and is executable"
        
        # Test help option
        if ./build-ios.sh --help >/dev/null 2>&1; then
            echo "✅ iOS build script help works"
        fi
    else
        echo "❌ iOS build script missing or not executable"
    fi
    
    echo ""
}

# Test Tauri configuration
test_tauri_config() {
    echo "⚙️  Testing Tauri configuration..."
    
    if [ -f "src-tauri/tauri.conf.json" ]; then
        echo "✅ tauri.conf.json exists"
        
        # Validate JSON syntax
        if command_exists jq; then
            jq empty src-tauri/tauri.conf.json 2>/dev/null && echo "✅ tauri.conf.json is valid JSON"
        elif command_exists python3; then
            python3 -m json.tool src-tauri/tauri.conf.json >/dev/null 2>&1 && echo "✅ tauri.conf.json is valid JSON"
        fi
        
        # Check for mobile-specific configuration
        if grep -q "identifier" src-tauri/tauri.conf.json; then
            echo "✅ App identifier found in config"
        fi
    else
        echo "❌ tauri.conf.json not found"
    fi
    
    echo ""
}

# Test Rust compilation
test_rust_compilation() {
    echo "🦀 Testing Rust compilation..."
    
    if command_exists cargo; then
        echo "✅ Cargo is available"
        
        # Check if project compiles
        cd src-tauri
        if cargo check --quiet 2>/dev/null; then
            echo "✅ Rust code compiles successfully"
        else
            echo "❌ Rust compilation failed"
            echo "Running cargo check for details:"
            cargo check
        fi
        cd ..
    else
        echo "❌ Cargo not found"
    fi
    
    echo ""
}

# Test platform-specific code
test_platform_code() {
    echo "🌐 Testing platform-specific code..."
    
    if [ -f "src-tauri/src/platform.rs" ]; then
        echo "✅ Platform module exists"
        
        # Check if platform module is included in lib.rs
        if grep -q "pub mod platform" src-tauri/src/lib.rs; then
            echo "✅ Platform module is included in lib.rs"
        else
            echo "❌ Platform module not included in lib.rs"
        fi
        
        # Check for platform-specific commands
        if grep -q "get_platform_info" src-tauri/src/commands.rs; then
            echo "✅ Platform-specific commands found"
        else
            echo "❌ Platform-specific commands missing"
        fi
    else
        echo "❌ Platform module not found"
    fi
    
    echo ""
}

# Generate summary report
generate_summary() {
    echo "📊 Build Configuration Summary"
    echo "=============================="
    
    local total_checks=0
    local passed_checks=0
    
    # Count checks (this is a simplified approach)
    echo "Android Configuration:"
    echo "  - AndroidManifest.xml: $([ -f "src-tauri/gen/android/app/src/main/AndroidManifest.xml" ] && echo "✅ Present" || echo "❌ Missing")"
    echo "  - Network Security Config: $([ -f "src-tauri/gen/android/app/src/main/res/xml/network_security_config.xml" ] && echo "✅ Present" || echo "❌ Missing")"
    echo "  - Build Script: $([ -f "build-android.sh" ] && [ -x "build-android.sh" ] && echo "✅ Present" || echo "❌ Missing")"
    
    echo ""
    echo "iOS Configuration:"
    echo "  - Info.plist: $([ -f "src-tauri/gen/ios/Info.plist" ] && echo "✅ Present" || echo "❌ Missing")"
    echo "  - Build Script: $([ -f "build-ios.sh" ] && [ -x "build-ios.sh" ] && echo "✅ Present" || echo "❌ Missing")"
    
    echo ""
    echo "Platform Support:"
    echo "  - Platform Module: $([ -f "src-tauri/src/platform.rs" ] && echo "✅ Present" || echo "❌ Missing")"
    echo "  - Tauri Config: $([ -f "src-tauri/tauri.conf.json" ] && echo "✅ Present" || echo "❌ Missing")"
    
    echo ""
    echo "🎯 Ready for mobile development!"
    echo "📱 Use './build-android.sh' to build for Android"
    echo "🍎 Use './build-ios.sh' to build for iOS (macOS only)"
}

# Main execution
main() {
    echo "🚀 Starting mobile build configuration tests..."
    echo ""
    
    test_android_config
    test_ios_config
    test_build_scripts
    test_tauri_config
    test_rust_compilation
    test_platform_code
    
    echo ""
    generate_summary
}

# Handle script arguments
case "${1:-}" in
    --android)
        test_android_config
        ;;
    --ios)
        test_ios_config
        ;;
    --scripts)
        test_build_scripts
        ;;
    --rust)
        test_rust_compilation
        ;;
    --help|-h)
        echo "Usage: $0 [--android|--ios|--scripts|--rust|--help]"
        echo "  --android: Test only Android configuration"
        echo "  --ios:     Test only iOS configuration"
        echo "  --scripts: Test only build scripts"
        echo "  --rust:    Test only Rust compilation"
        echo "  --help:    Show this help message"
        exit 0
        ;;
    *)
        main
        ;;
esac