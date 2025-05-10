# Swift gRPC Implementation

This project implements a gRPC client and server using Swift, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

- Swift 5.5 or higher
- Swift Package Manager
- Protocol Buffers compiler (protoc)
- macOS 10.15+ or Ubuntu 18.04+

## Building the Project

### 1. Build with Swift Package Manager

```bash
# Build the entire project
swift build

# Build in release mode
swift build -c release
```

### 2. Generate gRPC Code from Proto Files

```bash
# Generate Swift code from proto files
protoc -I ../proto ../proto/landing.proto \
  --swift_opt=Visibility=Public \
  --swift_out=./Sources/Common \
  --grpc-swift_opt=Visibility=Public \
  --grpc-swift_out=./Sources/Common
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
swift run HelloServer

# Terminal 2: Start the client
swift run HelloClient
```

### Proxy Mode

Swift implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
swift run HelloServer

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 swift run HelloServer

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 swift run HelloClient
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
   GRPC_HELLO_SECURE=Y swift run HelloServer
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y swift run HelloClient
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y swift run HelloServer
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y swift run HelloServer
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y swift run HelloClient
   ```

## Testing

### Using Swift's Built-in Testing Framework

As of Swift 6.1, Apple has introduced a built-in testing framework called "Swift Testing" which replaces XCTest. This project has been updated to use this new framework:

```bash
# Run tests with Swift Package Manager
swift test
```

## Troubleshooting

1. **Port Already in Use**
   ```bash
   # Find and kill processes using specific ports
   kill $(lsof -t -i:9996) 2>/dev/null || true
   kill $(lsof -t -i:9997) 2>/dev/null || true
   ```

2. **Check Service Logs**
   ```bash
   # View log files
   tail -f log/hello-grpc.log
   ```

3. **Swift Package Manager Issues**
   ```bash
   # Clean and rebuild
   swift package clean
   swift build
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| OS_LOG_LEVEL              | Control Swift logging levels              | default      |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Modern Swift concurrency with async/await
- ✅ Header propagation
- ✅ Structured logging with OSLog
- ✅ Custom testing framework (XCTest-independent)
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow Swift API design guidelines
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README