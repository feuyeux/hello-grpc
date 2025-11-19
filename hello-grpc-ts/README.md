# TypeScript gRPC Implementation

This project implements a gRPC client and server using TypeScript, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

| Component          | Version | Notes                                    |
|--------------------|---------|------------------------------------------|
| Node.js            | 24.7.0  | Node.js runtime                          |
| TypeScript         | 5.9.3   | TypeScript language (4.5+ supported)     |
| Build Tool         | 11.6.1  | npm, Node package manager (or yarn)      |
| gRPC               | 1.12.0  | @grpc/grpc-js                            |
| Protocol Buffers   | 3.21.4  | google-protobuf                          |
| grpc-tools         | 1.12.4  | Protocol Buffers compiler for Node.js    |

## Building the Project

### 1. Install Dependencies

```bash
# Install dependencies
npm install
# Or using yarn
yarn install
```

### 2. Generate gRPC Code from Proto Files

```bash
# Generate TypeScript code from proto files
npm run generate-proto
# Or manually:
protoc \
  --plugin=protoc-gen-ts_proto=./node_modules/.bin/protoc-gen-ts_proto \
  --ts_proto_out=./src/proto \
  --ts_proto_opt=outputServices=grpc-js,env=node,useOptionals=true \
  --proto_path=../proto ../proto/landing.proto
```

### 3. Build the Project

```bash
# Build the project
npm run build
# Or using yarn
yarn build
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
npm run server
# Or directly with ts-node:
npx ts-node src/server.ts

# Terminal 2: Start the client
npm run client
# Or directly with ts-node:
npx ts-node src/client.ts
```

### Proxy Mode

TypeScript implementation supports proxy mode, where the server can forward requests to another backend server:

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
# Run all tests
npm test

# Run specific test file to display version information
npm test -- test/utils.test.ts

# Or using yarn
yarn test
```

The utils.test.ts file has been enhanced to display version information about the gRPC package used in this project. When you run this specific test, it will output the current version of the @grpc/grpc-js package being used.

### Sample Output

```
=== TypeScript gRPC Version Information ===
grpc.js-version=^1.12.0
=========================================

Utils
  getVersion()
    ✔ should return a string starting with grpc.js-version=
    ✔ should return version that matches package.json version
```

### Version Check

This project includes utilities to verify the version of gRPC being used. You can use the `getVersion()` function from `common/utils.ts` in your own code to check which version of the gRPC.js library is being used:

```typescript
import { getVersion } from './common/utils';

console.log(`Current gRPC version: ${getVersion()}`);
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

3. **TypeScript Compilation Issues**
   ```bash
   # Clear build files and rebuild
   npm run clean
   npm run build
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
- ✅ Strong typing with TypeScript
- ✅ Promise-based API
- ✅ Async/await pattern
- ✅ Header propagation
- ✅ Structured logging with Winston
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow TypeScript best practices
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README