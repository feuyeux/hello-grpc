# Flutter gRPC Implementation

This project implements a gRPC client using Flutter, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Protocol Buffers compiler (protoc)
- Dart protoc plugin

## Quick Start

### 1. Setup Project

```bash
# Install Flutter dependencies
flutter pub get

# Link proto files from parent directory
./proto_link.sh

# Generate Dart code from proto files
protoc --dart_out=grpc:lib/src/generated -Iprotos protos/landing.proto
```

### 2. Enable Platform Support

```bash
# Enable Android and iOS support
flutter config --enable-android
flutter config --enable-ios

# Create platform configurations
flutter create --platforms=android,ios .
```

### 3. Configure Android NDK (if needed)

Update `android/local.properties`:
```properties
ndk.dir=/path/to/android-sdk/ndk/28.1.13356709
```

Update `android/app/build.gradle.kts`:
```kotlin
android {
    ndkVersion = "28.1.13356709"
}
```

### 4. Launch Emulators and Run

```bash
# Check available emulators
flutter emulators

# Launch Android emulator
flutter emulators --launch <android_emulator_id>

# Launch iOS simulator
flutter emulators --launch apple_ios_simulator

# Run on Android
flutter run -d <android_device_id>

# Run on iOS
flutter run -d <ios_device_id>
```

## Configuration

### Server Connection

```bash
# Set server address and port
export GRPC_SERVER=localhost
export GRPC_SERVER_PORT=9996
flutter run
```

### TLS Secure Communication

```bash
# Enable TLS
export GRPC_HELLO_SECURE=Y
flutter run
```

For TLS, place certificates in `assets/certs/` and update `pubspec.yaml`:
```yaml
assets:
  - assets/certs/
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| GRPC_HELLO_SECURE | Enable TLS encryption | N |
| GRPC_SERVER | Server address | localhost |
| GRPC_SERVER_PORT | Server port | 9996 |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication  
- ✅ Cross-platform (Android, iOS, macOS, Windows, Linux)
- ✅ Material Design UI
- ✅ Asynchronous programming with Futures and Streams
