# Java gRPC Implementation

## Overview

This directory contains the Java implementation of the Hello gRPC project, demonstrating all four gRPC communication patterns with enterprise-grade features including TLS security, proxy support, and comprehensive logging.

**Communication Patterns:**
1. **Unary RPC**: Simple request-response
2. **Server Streaming RPC**: Single request, multiple responses
3. **Client Streaming RPC**: Multiple requests, single response
4. **Bidirectional Streaming RPC**: Full-duplex communication

**Key Features:**
- ✅ All four gRPC communication models
- ✅ TLS/SSL secure communication
- ✅ Proxy mode for request forwarding
- ✅ Structured logging with SLF4J + Logback
- ✅ Graceful shutdown handling
- ✅ Retry logic with exponential backoff
- ✅ Docker support
- ✅ Maven build system
- ✅ JUnit 5 testing framework

## Prerequisites

**Required:**
- JDK 17 or higher (JDK 11+ supported)
- Maven 3.8 or higher
- Protocol Buffers compiler (protoc) 3.x

**Optional:**
- Docker (for containerized deployment)
- IntelliJ IDEA (recommended IDE)

**Installation:**

```bash
# Install JDK (if not already installed)
# macOS:
brew install openjdk@17

# Linux:
apt-get install openjdk-17-jdk

# Windows:
# Download from: https://adoptium.net/

# Verify installation
java -version
mvn -version

# Install protoc
# macOS:
brew install protobuf

# Linux:
apt-get install -y protobuf-compiler
```

## Building

### Using Consolidated Scripts (Recommended)

```bash
# Build Java implementation
../scripts/build/build-language.sh --language java

# Or with options
../scripts/build/build-language.sh --language java --clean --test --verbose
```

### Using Local Build Script

```bash
# Simple build
./build.sh

# Clean build
./build.sh --clean

# Build with tests
./build.sh --test
```

### Using Maven Directly

```bash
# Build server
mvn clean package -f server_pom.xml

# Build client
mvn clean package -f client_pom.xml

# Build both
mvn clean package
```

**Build Output:**
- Server JAR: `target/hello-grpc-java-server.jar`
- Client JAR: `target/hello-grpc-java-client.jar`
- Generated code: `target/generated-sources/protobuf/`

**Note:** Protocol Buffer code generation is handled automatically by the `protobuf-maven-plugin` during the build process.

## Running

### Using Consolidated Scripts (Recommended)

```bash
# Terminal 1: Start server
../scripts/deployment/start-server.sh --language java

# Terminal 2: Start client
../scripts/deployment/start-client.sh --language java
```

### Using Local Scripts

```bash
# Terminal 1: Start server
./server_start.sh

# Terminal 2: Start client
./client_start.sh
```

### Direct Execution

```bash
# Terminal 1: Start server
java -jar target/hello-grpc-java-server.jar

# Terminal 2: Start client
java -jar target/hello-grpc-java-client.jar
```

**Expected Output:**

Server:
```
[2025-01-15 10:30:45.123] [INFO] [ProtoServer] Starting gRPC server on port 9996
[2025-01-15 10:30:50.456] [INFO] [LandingServiceImpl] Received unary request
```

Client:
```
[2025-01-15 10:30:50.123] [INFO] [ProtoClient] Starting unary RPC call
[2025-01-15 10:30:50.789] [INFO] [ProtoClient] Received response: Hello from Java
```

### Proxy Mode

Java implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
java -jar target/hello-grpc-java-server.jar

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 java -jar target/hello-grpc-java-server.jar

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 java -jar target/hello-grpc-java-client.jar
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
   GRPC_HELLO_SECURE=Y java -jar target/hello-grpc-java-server.jar
   # Or using sh script:
   sh server_start.sh --tls

   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y java -jar target/hello-grpc-java-client.jar
   # Or using sh script:
   sh client_start.sh --tls
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y java -jar target/hello-grpc-java-server.jar
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y java -jar target/hello-grpc-java-server.jar
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y \
   java -jar target/hello-grpc-java-client.jar
   ```

## Testing

```bash
# Run tests with Maven
mvn test
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

3. **JAVA_HOME Not Set**
   ```bash
   # For macOS
   export JAVA_HOME=$(/usr/libexec/java_home)
   # For Linux
   export JAVA_HOME=/path/to/your/java/installation
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
- ✅ Service discovery integration
- ✅ Header propagation
- ✅ Robust logging with SLF4J
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow the Java coding standards and project structure
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README