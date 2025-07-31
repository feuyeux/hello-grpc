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
- Android Studio or VS Code with Flutter extensions

## Building the Project

### 1. Install Dependencies

```bash
# https://docs.flutter.dev/get-started/install
# Install Flutter dependencies
flutter pub get

# Install the protoc plugin globally (if not already installed)
dart pub global activate protoc_plugin
```

### 2. Setup Proto Files

```bash
# Link proto files from parent directory
./proto_link.sh
```

### 3. Generate gRPC Code from Proto Files

```bash
# Generate Dart code from proto files
protoc --dart_out=grpc:lib/src/generated -Iprotos protos/landing.proto
```

## Running the Application

### Application Setup

```bash
# Run the Flutter app on mobile/desktop
flutter run

# Build for specific platform
flutter build apk     # Android
flutter build ios     # iOS (on macOS only)  
flutter build macos   # macOS desktop
flutter build windows # Windows desktop
flutter build linux   # Linux desktop
```

### Connecting to Backend

The Flutter client can connect to any of the server implementations using the environment variables:

```bash
# Connect to a specific server before running the app
export GRPC_SERVER=localhost
export GRPC_SERVER_PORT=9996
flutter run
```

### TLS Secure Communication

To enable TLS, you need to prepare certificates and configure environment variables:

1. **Certificate Setup**

   Place client certificates in the app's asset directory:
   ```bash
   # Copy certificates to the app's assets directory
   mkdir -p assets/certs
   cp /var/hello_grpc/client_certs/* assets/certs/
   ```

2. **Update pubspec.yaml**

   Ensure that the certificates are included in the app bundle:
   ```yaml
   assets:
     - assets/certs/
   ```

3. **Run with TLS Enabled**

   ```bash
   # Start a gRPC server with TLS enabled in another terminal
   # Then run the Flutter app with TLS enabled
   export GRPC_HELLO_SECURE=Y
   flutter run
   ```

## Testing

```bash
# Run tests
flutter test
```

## Troubleshooting

1. **Certificate Issues**
   ```bash
   # Make sure certificates are included in assets
   flutter clean
   flutter pub get
   ```

2. **Connection Issues**
   ```bash
   # Ensure the server is running and accessible
   # For Android emulators, use 10.0.2.2 instead of localhost
   export GRPC_SERVER=10.0.2.2
   flutter run
   ```

3. **Build Issues**
   ```bash
   # Clean and rebuild
   flutter clean
   flutter pub get
   flutter run
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| NO_PROXY                  | Bypass proxy for certain addresses        | N/A          |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication  
- ✅ Cross-platform (Android, iOS, macOS, Windows, Linux)
- ✅ Material Design UI
- ✅ Asynchronous programming with Futures and Streams
- ✅ Dynamic server configuration
- ✅ Automatic local IP detection
- ✅ Null safety support

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow Flutter and Dart style guidelines
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
