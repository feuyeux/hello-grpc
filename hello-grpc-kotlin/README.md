# Kotlin gRPC Implementation

This project implements a gRPC client and server using Kotlin, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

- JDK 11 or higher
- Gradle 7.0+ (wrapper included)
- Protocol Buffers compiler (protoc)

## Building the Project

### 1. Building with Gradle

```bash
# Build the entire project
./gradlew build

# Build server and client separately
./gradlew :server:build
./gradlew :client:build
```

### 2. Generate gRPC Code from Proto Files

The Gradle build automatically generates the gRPC code using the `protobuf-gradle-plugin`.

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
sh server_start.sh
# Or using gradle directly:
./gradlew :server:run

# Terminal 2: Start the client
sh client_start.sh
# Or using gradle directly:
./gradlew :client:run
```

### Proxy Mode

Kotlin implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
./gradlew :server:run

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 ./gradlew :server:run

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 ./gradlew :client:run
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
   GRPC_HELLO_SECURE=Y ./gradlew :server:run
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y ./gradlew :client:run
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y ./gradlew :server:run
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y ./gradlew :server:run
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y ./gradlew :client:run
   ```

## Testing

```bash
# Run tests with Gradle
./gradlew test
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

3. **Gradle Wrapper Issues**
   ```bash
   # Re-download the Gradle wrapper if needed
   gradle wrapper
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| GRPC_HELLO_DISCOVERY      | Service discovery method                  | N/A          |
| GRPC_HELLO_DISCOVERY_ENDPOINT | Service discovery endpoint            | N/A          |
| JAVA_HOME                 | Java installation path                    | N/A          |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Kotlin coroutines integration
- ✅ Modern Kotlin DSL Gradle configuration
- ✅ Header propagation
- ✅ Advanced logging
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow the Kotlin coding conventions
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
