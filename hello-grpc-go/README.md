# Go gRPC Implementation

## Overview

This directory contains the Go implementation of the Hello gRPC project, demonstrating all four gRPC communication patterns with production-ready features including TLS security, proxy support, and structured logging.

**Communication Patterns:**
1. **Unary RPC**: Simple request-response
2. **Server Streaming RPC**: Single request, multiple responses
3. **Client Streaming RPC**: Multiple requests, single response
4. **Bidirectional Streaming RPC**: Full-duplex communication

**Key Features:**
- ✅ All four gRPC communication models
- ✅ TLS/SSL secure communication
- ✅ Proxy mode for request forwarding
- ✅ Structured logging with logrus
- ✅ Graceful shutdown handling
- ✅ Retry logic with exponential backoff
- ✅ Docker support
- ✅ Environment-based configuration

## Prerequisites

**Required:**
- Go 1.21 or higher
- Protocol Buffers compiler (protoc) 3.x
- Go protocol buffers plugins

**Optional:**
- Docker (for containerized deployment)
- Make (for build automation)

**Installation:**

```bash
# Install Go (if not already installed)
# Visit: https://golang.org/doc/install
# brew install go

# Install protoc
# macOS:
brew install protobuf

# Linux:
apt-get install -y protobuf-compiler

# Windows:
# Download from: https://github.com/protocolbuffers/protobuf/releases

# Install Go plugins
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

## Building

### Using Local Build Script

```bash
# Simple build
./build.sh

# Clean build
./build.sh --clean

# Build with tests
./build.sh --test
```

### Manual Build Steps

If you need to build manually:

```bash
# 1. Install dependencies
go mod tidy

# 2. Create output directory
mkdir -p ./common/pb

# 3. Generate Protocol Buffer code
protoc -I ../proto \
  --go_out=./common/pb --go_opt=paths=source_relative \
  --go-grpc_out=./common/pb --go-grpc_opt=paths=source_relative \
  ../proto/landing.proto

# 4. Build binaries
go build -o bin/server ./server
go build -o bin/client ./client
```

**Important Notes:**
- Protocol Buffer files must be generated in `common/pb/` directory
- Generating in `common/` directly will cause package naming conflicts
- The build script handles all these steps automatically

**Build Output:**
- Server binary: `bin/server`
- Client binary: `bin/client`
- Generated code: `common/pb/*.pb.go`

## Running

### Using Consolidated Scripts (Recommended)

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
go run server/main.go

# Terminal 2: Start client
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

   Using command-line flags (recommended):
   ```bash
   # Terminal 1: Start the server with TLS
   ./server_start.sh --tls
   
   # Terminal 2: Start the client with TLS
   ./client_start.sh --tls
   ```

   Or using environment variables (backward compatible):
   ```bash
   # Terminal 1: Start the server with TLS
   GRPC_HELLO_SECURE=Y go run server/proto_server.go
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y go run client/proto_client.go
   ```

   Or directly with the Go programs:
   ```bash
   # Terminal 1: Start the server with TLS
   go run server/proto_server.go --tls
   
   # Terminal 2: Start the client with TLS
   go run client/proto_client.go --tls
   ```

   **Note:** If both the `--tls` flag and `GRPC_HELLO_SECURE` environment variable are set, the `--tls` flag takes precedence.

3. **TLS with Proxy**

   Using command-line flags:
   ```bash
   # Terminal 1: Start the backend server with TLS
   ./server_start.sh --tls
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   ./server_start.sh --tls
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 ./client_start.sh --tls
   ```

   Or using environment variables:
   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y go run server/proto_server.go
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y go run server/proto_server.go
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y go run client/proto_client.go
   ```

## Testing

### Using Consolidated Scripts

```bash
# Run tests for Go implementation
../scripts/testing/run-tests.sh --language go
```

### Using Go Test

```bash
# Run all tests
go test ./...

# Run tests with verbose output
go test -v ./...

# Run tests for specific package
go test ./common

# Run specific test
go test -v ./common -run TestGetAnswerMap

# Run tests with coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Test Structure

```
tests/
├── client_test.go      # Client tests
├── server_test.go      # Server tests
└── utils_test.go       # Utility tests
```


## Configuration

### Environment Variables

| Variable | Description | Default | Example |
|:---------|:------------|:--------|:--------|
| `GRPC_SERVER` | Server address (client) | `localhost` | `192.168.1.100` |
| `GRPC_SERVER_PORT` | Server port | `9996` | `8080` |
| `GRPC_HELLO_SECURE` | Enable TLS | `N` | `Y` |
| `GRPC_HELLO_BACKEND` | Backend server (proxy) | - | `localhost` |
| `GRPC_HELLO_BACKEND_PORT` | Backend port (proxy) | - | `9997` |
| `GRPC_GO_LOG_SEVERITY_LEVEL` | Log severity | `info` | `debug` |
| `GRPC_GO_LOG_VERBOSITY_LEVEL` | Log verbosity | `0` | `2` |

### Configuration Files

- `common/logging_config.go`: Logging configuration
- `common/connection.go`: Connection settings
- `common/error_mapper.go`: Error handling configuration

### TLS Certificates

Certificate locations:
- Server: `/var/hello_grpc/server_certs/`
- Client: `/var/hello_grpc/client_certs/`

Required files:
- `cert.pem`: Certificate
- `private.key`: Private key
- `full_chain.pem`: Certificate chain
- `myssl_root.cer`: Root CA certificate

Generate certificates:
```bash
../scripts/certificates/generate-certificates.sh
../scripts/certificates/copy-certificates.sh --language go
```

## Troubleshooting

### Common Issues

**1. Port Already in Use**

```bash
# Using consolidated script
../scripts/utilities/kill-port.sh 9996

# Or manually
lsof -ti:9996 | xargs kill -9
```

**2. Build Failures**

```bash
# Check dependencies
../scripts/utilities/check-dependencies.sh --language go

# Clean and rebuild
./build.sh --clean
go mod tidy
go mod download
```

**3. Protocol Buffer Generation Errors**

```bash
# Verify protoc installation
protoc --version

# Verify Go plugins
which protoc-gen-go
which protoc-gen-go-grpc

# Reinstall plugins if needed
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

**4. Connection Errors**

```bash
# Check if server is running
lsof -i:9996

# Check logs
tail -f logs/hello_server.log

# Test connectivity
telnet localhost 9996
```

**5. TLS Certificate Errors**

```bash
# Verify certificate files exist
ls -la /var/hello_grpc/server_certs/
ls -la /var/hello_grpc/client_certs/

# Check certificate validity
openssl x509 -in /var/hello_grpc/server_certs/cert.pem -text -noout

# Regenerate certificates
../scripts/certificates/generate-certificates.sh
```

**6. Module/Import Errors**

```bash
# Clear module cache
go clean -modcache

# Update dependencies
go get -u ./...
go mod tidy
```

### Debugging

Enable debug logging:
```bash
export GRPC_GO_LOG_SEVERITY_LEVEL=debug
export GRPC_GO_LOG_VERBOSITY_LEVEL=2
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all
```

View logs:
```bash
# Server logs
tail -f logs/hello_server.log

# Client logs
tail -f logs/hello_client.log

# All logs
tail -f logs/*.log
```

### Getting Help

1. Check [main documentation](../docs/)
2. Review [troubleshooting guide](../docs/TROUBLESHOOTING.md)
3. Search [existing issues](https://github.com/feuyeux/hello-grpc/issues)
4. Ask in [discussions](https://github.com/feuyeux/hello-grpc/discussions)

## Project Structure

```
hello-grpc-go/
├── client/
│   └── proto_client.go      # Client implementation
├── server/
│   ├── proto_server.go      # Server implementation
│   └── service_impl.go      # Service implementation
├── common/
│   ├── pb/                  # Generated protobuf code
│   ├── connection.go        # Connection management
│   ├── error_mapper.go      # Error handling
│   ├── log_formatter.go     # Logging configuration
│   ├── logging_config.go    # Logger setup
│   ├── shutdown.go          # Graceful shutdown
│   ├── utils.go             # Utility functions
│   └── utils_test.go        # Utility tests
├── logs/                    # Log files
├── bin/                     # Compiled binaries
├── build.sh                 # Build script
├── server_start.sh          # Server startup
├── client_start.sh          # Client startup
├── go.mod                   # Go module definition
├── go.sum                   # Dependency checksums
└── README.md                # This file
```

## Docker Support

### Build Docker Image

```bash
# Using consolidated script
cd ..
docker build -f docker/go_grpc.dockerfile -t hello-grpc-go:latest .

# Or manually
docker build -t hello-grpc-go:latest .
```

### Run in Docker

```bash
# Start server
docker run -p 9996:9996 hello-grpc-go:latest server

# Start client
docker run --network host hello-grpc-go:latest client
```

## Advanced Usage

### Proxy Mode

Forward requests through a proxy server:

```bash
# Terminal 1: Backend server
./server_start.sh

# Terminal 2: Proxy server
GRPC_SERVER_PORT=9997 \
GRPC_HELLO_BACKEND=localhost \
GRPC_HELLO_BACKEND_PORT=9996 \
./server_start.sh

# Terminal 3: Client
GRPC_SERVER_PORT=9997 ./client_start.sh
```

### Service Discovery

Integration with etcd for service discovery:

```bash
# Start with etcd
GRPC_HELLO_ETCD_ENDPOINTS=localhost:2379 ./server_start.sh
GRPC_HELLO_ETCD_ENDPOINTS=localhost:2379 ./client_start.sh
```

## References

- [Go gRPC Documentation](https://grpc.io/docs/languages/go/)
- [Protocol Buffers Go Tutorial](https://protobuf.dev/getting-started/gotutorial/)
- [Go Modules Reference](https://go.dev/ref/mod)
- [Logrus Documentation](https://github.com/sirupsen/logrus)

## License

This project is part of the Hello gRPC repository. See [LICENSE](../LICENSE) for details.
