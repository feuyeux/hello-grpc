# Rust gRPC Implementation

This project implements a gRPC client and server using Rust, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

- Rust 1.70 or higher (recommended)
- Cargo (Rust package manager)
- Protocol Buffers compiler (protoc)

## Building the Project

### 1. Install Required Tools

```bash
# Install Rust with rustup if you haven't already
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install protobuf compiler plugin for Rust if needed
export RUSTUP_DIST_SERVER="https://mirrors.tuna.tsinghua.edu.cn/rustup"
cargo install protobuf-codegen
cargo install tonic-build
```

### 2. Generate gRPC Code from Proto Files

The code generation is configured in `build.rs` and happens automatically during build, but you can also trigger it with:

```bash
# Generate Rust code from proto files
cargo build

$ find . -name "*.rs"

./target/debug/build/hello-grpc-rust-b1aedb8eb000afe4/out/org.feuyeux.grpc.rs
./target/debug/build/anyhow-db0336bb83000618/out/probe.rs
./build.rs
./main.rs
./src/client.rs
./src/server.rs
```

### 3. Build the Project

```bash
# Build in development mode
cargo build

# Build in release mode
cargo build --release
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
cargo run --bin server

# Terminal 2: Start the client
cargo run --bin client
```

### Proxy Mode

Rust implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
cargo run --bin server

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 cargo run --bin server

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 cargo run --bin client
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
   GRPC_HELLO_SECURE=Y cargo run --bin server
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y cargo run --bin client
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y cargo run --bin server
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y cargo run --bin server
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y cargo run --bin client
   ```

## Testing

```bash
# Run all tests
cargo test

# Run specific test file with visible output
cargo test --test version_test -- --nocapture
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
   RUST_LOG=trace cargo run --bin server
   ```

3. **Cargo Issues**
   ```bash
   # Clean and rebuild
   cargo clean
   cargo build
   ```

```bash
# https://doc.rust-lang.org/nightly/rustc/platform-support.html
# https://doc.rust-lang.org/edition-guide/rust-2018/platform-and-target-support/musl-support-for-fully-static-binaries.html
rustup update
rustup target add x86_64-unknown-linux-musl
rustup show

# 1 error: linking with `cc` failed: exit code: 1
# clang: error: linker command failed with exit code 1 (use -v to see invocation)
# `brew install FiloSottile/musl-cross/musl-cross`
# `ln -s /usr/local/bin/x86_64-linux-musl-gcc /usr/local/bin/musl-gcc`

# 2 Error: Your CLT does not support macOS 11.2.
# `sudo rm -rf /Library/Developer/CommandLineTools`
# `sudo xcode-select --install`

# https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_12.5_beta/Command_Line_Tools_for_Xcode_12.5_beta.dmg
# https://download.developer.apple.com/Developer_Tools/Command_Line_Tools_for_Xcode_13/Command_Line_Tools_for_Xcode_13.dmg
# `/usr/bin/xcodebuild -version`
# xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
# `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`

# `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables`
# package-id: com.apple.pkg.CLTools_Executables
# version: 12.5.0.0.1.1611946261
# volume: /
# location: /
# install-time: 1612700387
# groups: com.apple.FindSystemFiles.pkg-group

CROSS_COMPILE=x86_64-linux-musl-gcc cargo build --release --bin proto-server --target=x86_64-unknown-linux-musl
```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| RUST_LOG                  | Control Rust logging levels               | info         |
| RUST_BACKTRACE            | Enable backtraces for debugging           | 0            |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Async programming with Tokio
- ✅ Memory and thread safety guarantees
- ✅ Header propagation
- ✅ Structured logging with tracing
- ✅ Environment variable configuration
- ✅ gRPC and protoc version reporting

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow Rust's style guidelines
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
