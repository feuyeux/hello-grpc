# Dart gRPC Implementation

This project implements a gRPC client and server using Dart, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

- Dart SDK 3.7.0 or higher
- Protocol Buffers compiler (protoc)
- Dart protoc plugin

## Building the Project

### 1. Install Dependencies

```bash
# Install Dart dependencies
dart pub get

# Install the protoc plugin globally
dart pub global activate protoc_plugin
```

### 2. Generate gRPC Code from Proto Files

```bash
# Generate Dart code from proto files
protoc -I ../proto/ ../proto/landing.proto --dart_out=grpc:lib/common \
--plugin=protoc-gen-dart="$(which protoc-gen-dart)"

# Windows specific path
# --plugin=protoc-gen-dart="C:\Users\username\AppData\Local\Pub\Cache\bin\protoc-gen-dart.bat"
```

### 3. Compile Executables (Optional)

```bash
# Compile server and client to native executables
dart compile exe server.dart -o bin/hello_server
dart compile exe client.dart -o bin/hello_client
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
dart server.dart
# Or using the compiled binary
# ./bin/hello_server

# Terminal 2: Start the client
dart client.dart
# Or using the compiled binary
# ./bin/hello_client
```

### Proxy Mode

Dart implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
dart server.dart

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 dart server.dart

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 dart client.dart
```

### TLS Secure Communication

To enable TLS, you need to prepare certificates and configure environment variables:

1. **Certificate Setup**

   Verify the certificate structure:
   ```bash
   # Server certificates
   ls -la /var/hello_grpc/server_certs
   # Should contain: cert.pem, private.key, private.pkcs8.key, full_chain.pem, myssl_root.cer
   
   # Client certificates
   ls -la /var/hello_grpc/client_certs
   # Should contain: cert.pem, private.key, private.pkcs8.key, full_chain.pem, myssl_root.cer
   ```

2. **Direct TLS Connection**

   ```bash
   # Terminal 1: Start the server with TLS
   GRPC_HELLO_SECURE=Y dart server.dart
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y dart client.dart
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y dart server.dart
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y dart server.dart
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y dart client.dart
   ```

## Testing

To run tests on the Dart implementation:

```bash
# Run all tests
dart test

# Run specific test file
dart test test/utils_test.dart
```

### Available Tests

- **Utils Tests (`test/utils_test.dart`)**: Tests utility functions like version detection, timestamp, and UUID generation.
- **Connection Config Tests (`test/conn_test.dart`)**: Tests connection configuration logic, including environment variable handling for ports, security, and certificate paths.
- **Client Tests (`test/client_test.dart`)**: Tests client-side gRPC calls (unary and streaming) using a mock gRPC service.
- **Server Tests (`test/server_test.dart`)**: Tests server-side gRPC handlers (unary and streaming) by directly invoking service implementation methods with a mock `ServiceCall`.

## Troubleshooting

### Common Issues

1. **Connection Refused**
   - Ensure the server is running before the client
   - Verify the port is not in use by another application

2. **Certificate Issues in TLS Mode**
   - Validate certificate paths are correctly set
   - Check certificate validity and expiration dates

3. **Dependency Issues**
   - Run `dart pub get` to refresh dependencies
   - Make sure Dart SDK version meets requirements

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| GRPC_SERVER | Server hostname | localhost |
| GRPC_SERVER_PORT | Server port | 9996 |
| GRPC_HELLO_BACKEND | Backend server hostname for proxy mode | localhost |
| GRPC_HELLO_BACKEND_PORT | Backend server port for proxy mode | 9996 |
| GRPC_TLS_CERT | Path to TLS certificate | ../docker/tls/server.crt |
| GRPC_TLS_KEY | Path to TLS key | ../docker/tls/server.key |
| GRPC_TLS_CA | Path to CA certificate | ../docker/tls/ca.crt |
| GRPC_HELLO_SECURE | Enable secure communication | N |

## Features

- Basic gRPC communication with all four patterns
- Proxy mode for request forwarding
- TLS secure communication
- Command line argument support
- Environment variable configuration
- Version detection and reporting
- UUID generation for request tracking

## Package Dependencies

This project depends on the following Dart packages:

- grpc: ^4.0.1 - Core gRPC functionality
- protobuf: ^4.0.0 - Protocol buffer support
- async: ^2.11.0 - Asynchronous programming utilities
- logging: ^1.2.0 - Logging infrastructure
- uuid: ^4.5.1 - UUID generation
- path: ^1.9.0 - File path operations
- test: ^1.25.8 - Testing framework

## Contributor Notes

When contributing to this project, please ensure all tests pass before submitting your changes. Follow the standard Dart style guide for code formatting.

Last updated: May 2025
