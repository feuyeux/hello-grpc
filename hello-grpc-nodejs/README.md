# Node.js gRPC Implementation

This project implements a gRPC client and server using Node.js, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

| Component          | Version | Notes                                    |
|--------------------|---------|------------------------------------------|
| Node.js            | 24.7.0  | Node.js runtime                          |
| Build Tool         | 11.6.1  | npm, Node package manager (or yarn)      |
| gRPC               | 1.13.3  | @grpc/grpc-js                            |
| Protocol Buffers   | 3.21.2  | google-protobuf                          |
| grpc-tools         | 1.12.4  | Protocol Buffers compiler for Node.js    |

## Building the Project

### 1. Install Dependencies

```bash
# Configure npm registry if needed
npm config set registry https://registry.npmmirror.com

# Remove proxy settings if necessary
npm config delete proxy
npm config delete https-proxy

# Install dependencies
npm install
# Or using yarn
yarn install
```

### 2. Generate gRPC Code from Proto Files

```bash
# Generate JavaScript code from proto files
npm run generate-proto
# Or manually:
protoc \
  --js_out=import_style=commonjs,binary:./src/proto \
  --grpc_out=grpc_js:./src/proto \
  --plugin=protoc-gen-grpc=`which grpc_tools_node_protoc_plugin` \
  --proto_path=../proto ../proto/landing.proto
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
npm run server
# Or directly with Node:
node src/server.js

# Terminal 2: Start the client
npm run client
# Or directly with Node:
node src/client.js
```

### Proxy Mode

Node.js implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
npm run server

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 npm run server

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 npm run client
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
   GRPC_HELLO_SECURE=Y npm run server
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y npm run client
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y npm run server
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y npm run server
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y npm run client
   ```

## Testing

```bash
# Run tests
npm test
# Or using yarn
yarn test
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
   tail -f logs/hello-grpc.log
   ```

3. **Node.js Dependency Issues**
   ```bash
   # Clear npm cache and reinstall
   npm cache clean --force
   rm -rf node_modules
   npm install
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| NODE_ENV                  | Node.js environment                       | development  |
| LOG_LEVEL                 | Logging level                             | info         |
| GRPC_VERBOSITY            | Set gRPC verbosity level (debug)          | N/A          |
| GRPC_TRACE                | Enable gRPC tracing (debug)               | N/A          |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Promise-based API
- ✅ Async/await pattern
- ✅ Header propagation
- ✅ Structured logging
- ✅ Environment variable configuration
- ✅ gRPC version reporting

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow Node.js and JavaScript best practices
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
