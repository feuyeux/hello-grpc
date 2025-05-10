# Go gRPC Implementation

This project implements a gRPC client and server using Go, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

- Go 1.16 or higher
- Protocol Buffers compiler (protoc)
- Go protocol buffers plugins

## Building the Project

### 1. Install Required Tools

```bash
go mod tidy

# Install protocol buffer compiler plugins for Go
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### 2. Generate gRPC Code from Proto Files

```bash
# First, create the pb directory inside common
mkdir -p ./common/pb

# Generate Go code from proto files
protoc -I ../proto \
  --go_out=./common/pb --go_opt=paths=source_relative \
  --go-grpc_out=./common/pb --go-grpc_opt=paths=source_relative \
  ../proto/landing.proto
```

> **IMPORTANT**: The Protocol Buffer files must be generated in the `common/pb` directory with the correct package name. If you generate them directly in the `common` directory, you'll encounter package naming conflicts.

### 3. Build the Project

```bash
# Build server
go build -o bin/server ./server

# Build client
go build -o bin/client ./client

# Or use the build script
./build.sh
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
go run server/main.go

# Terminal 2: Start the client
go run client/main.go
```

### Proxy Mode

Go implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
go run server/main.go

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 go run server/main.go

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 go run client/main.go
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
   GRPC_HELLO_SECURE=Y go run server/main.go
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y go run client/main.go
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y go run server/main.go
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y go run server/main.go
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y go run client/main.go
   ```

## Testing

```bash
# Run all tests in the project
go test ./...

# Run tests for a specific package
go test ./common

# Run a specific test
go test -v ./common -run TestGetAnswerMap
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

3. **Go Module Issues**
   ```bash
   # Reset and update modules
   go mod tidy
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| GRPC_HELLO_ETCD_ENDPOINTS | ETCD service discovery endpoints          | N/A          |
| GRPC_GO_LOG_SEVERITY_LEVEL| Go gRPC log severity level                | info         |
| GRPC_GO_LOG_VERBOSITY_LEVEL| Go gRPC log verbosity level              | 0            |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ ETCD service discovery
- ✅ Structured logging with zap
- ✅ Header propagation
- ✅ Middleware/interceptor support
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow Go coding standards and project structure
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
5. Always generate Protocol Buffer files in the correct directory structure (common/pb)
