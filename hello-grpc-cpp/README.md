# C++ gRPC Implementation

This project implements a gRPC client and server using C++, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

| Component          | Version | Notes                                    |
|--------------------|---------|------------------------------------------|
| C++ Standard       | C++17   | Clang 17.0.0 (Apple clang)               |
| Build Tool         | 8.4.2   | Bazel build system                       |
| gRPC               | 1.65.0  | grpc library                             |
| Protocol Buffers   | 26.0    | protobuf library (26.0.bcr.2)            |
| CMake              | 3.15+   | Alternative build system (optional)      |

## Building the Project

### 1. Using Bazel (Recommended)

The simplest way to build the project is using the provided build script:

```bash
# Build the project
./build.sh

# Build the project after cleaning previous build artifacts
./build.sh --clean
```

The build script:
- Uses multi-threading for faster builds
- Builds both server and client in one command
- Automatically manages dependencies with Bazel
- Disables building of non-C++ language plugins to avoid unnecessary compilation

The optimized build configuration includes:
- `--define=grpc_build_grpc_csharp_plugin=false` - Disables C# plugin build
- `--define=grpc_build_grpc_node_plugin=false` - Disables Node.js plugin build
- `--define=grpc_build_grpc_objective_c_plugin=false` - Disables Objective-C plugin build
- `--define=grpc_build_grpc_php_plugin=false` - Disables PHP plugin build
- `--define=grpc_build_grpc_python_plugin=false` - Disables Python plugin build
- `--define=grpc_build_grpc_ruby_plugin=false` - Disables Ruby plugin build
- Additional flags to optimize MacOS/Apple platform configuration

You can also build manually with:

```bash
# Build specific targets with optimized flags
bazel build \
    --cxxopt="-std=c++17" \
    --define=grpc_build_grpc_csharp_plugin=false \
    --define=grpc_build_grpc_node_plugin=false \
    --define=grpc_build_grpc_objective_c_plugin=false \
    --define=grpc_build_grpc_php_plugin=false \
    --define=grpc_build_grpc_python_plugin=false \
    --define=grpc_build_grpc_ruby_plugin=false \
    //:hello_server //:hello_client
```

### 2. Using CMake (Alternative)

```bash
# Create build directory
mkdir -p build && cd build

# Configure project
cmake ..

# Build the project
cmake --build .
```

### 3. Generate gRPC Code from Proto Files (Manual)

```bash
# If not using automated build systems
protoc -I../proto --cpp_out=. --grpc_out=. \
  --plugin=protoc-gen-grpc=`which grpc_cpp_plugin` \
  ../proto/landing.proto
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
./server_start.sh
# Or manually with bazel:
bazel run //server:hello_server

# Terminal 2: Start the client
./client_start.sh
# Or manually with bazel:
bazel run //client:hello_client
```

### Proxy Mode

C++ implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
./server_start.sh

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 ./server_start.sh

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 ./client_start.sh
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
   GRPC_HELLO_SECURE=Y ./server_start.sh
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y ./client_start.sh
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y ./server_start.sh
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y ./server_start.sh
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y ./client_start.sh
   ```

## Testing

The project includes unit tests using the Catch2 testing framework. These tests verify core utility functions and gRPC version retrieval.

```bash
# Run all tests with bazel
bazel test //tests:all

# Run specific unit test
bazel test //tests:hello_test

bazel test --test_output=all --cxxopt="-std=c++17" --host_cxxopt="-std=c++17" //tests:hello_test
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

3. **Bazel Build Issues**
   
   如果遇到Bazel构建问题，请尝试：
   ```bash
   # 清理Bazel构建文件
   bazel clean --expunge
   
   # 使用简单的构建命令
   bazel build -c opt //:hello_server //:hello_client
   ```

4. **Plugin Build Warnings**
   
   我们已经通过向构建命令添加 `--define=grpc_build_grpc_*_plugin=false` 标志来解决gRPC其他语言插件的警告：
   ```
   WARNING: target 'grpc_csharp_plugin' is both a rule and a file...
   ```
   现在这些警告不应该再出现了。如果它们仍然出现，确保使用最新版本的 `build.sh` 脚本。

5. **Apple DottedVersion Errors**
   
   如果遇到以下错误：
   ```
   com.google.devtools.build.lib.rules.apple.DottedVersion$InvalidDottedVersionException: 
   Dotted version components must all start with the form \d+([a-z0-9]*?)?(\d+)? but got 'None'
   ```
   
   这是macOS环境中的已知问题，我们已经添加了 `--incompatible_enable_cc_toolchain_resolution=false` 和其他标志来解决此问题。

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| GRPC_VERBOSITY            | Set gRPC verbosity level (debug)          | N/A          |
| GRPC_TRACE                | Enable gRPC tracing (debug)               | N/A          |
| GRPC_CPP_LOG_SEVERITY     | C++ logging severity level                | info         |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Multi-threaded server architecture
- ✅ Structured logging
- ✅ Header propagation
- ✅ Bazel and CMake build systems
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow Google C++ Style Guide
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README