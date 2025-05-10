# C# gRPC Implementation

This project implements a gRPC client and server using C#, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

> - Download .NET SDK <https://dotnet.microsoft.com/en-us/download/visual-studio-sdks>
> - What is .NET SDK <https://learn.microsoft.com/en-us/dotnet/core/sdk>

- .NET 6.0 SDK or higher
- Protocol Buffers compiler (protoc)
- Visual Studio 2022 or Visual Studio Code (optional)

## Version Information

This implementation uses:
- gRPC version: 2.61.0
- .NET target framework: net9.0

You can check the current gRPC version in your implementation by running the version test:

```bash
dotnet test --filter "FullyQualifiedName=HelloUT.Tests.OutputVersionInfo"
```

## Building the Project

### 1. Building with .NET CLI

```bash
# Build the solution
dotnet build HelloGrpc.sln

# Build server and client separately
dotnet build HelloServer/HelloServer.csproj
dotnet build HelloClient/HelloClient.csproj
```

### 2. Generate gRPC Code from Proto Files

The build process automatically generates the gRPC code using the `Grpc.Tools` NuGet package.

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
sh server_start.sh
# Or using dotnet directly:
dotnet run --project HelloServer/HelloServer.csproj

# Terminal 2: Start the client
sh client_start.sh
# Or using dotnet directly:
dotnet run --project HelloClient/HelloClient.csproj
```

### Proxy Mode

C# implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
dotnet run --project HelloServer/HelloServer.csproj

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 dotnet run --project HelloServer/HelloServer.csproj

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 dotnet run --project HelloClient/HelloClient.csproj
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
   GRPC_HELLO_SECURE=Y dotnet run --project HelloServer/HelloServer.csproj
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y dotnet run --project HelloClient/HelloClient.csproj
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y dotnet run --project HelloServer/HelloServer.csproj
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y dotnet run --project HelloServer/HelloServer.csproj
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y \
   dotnet run --project HelloClient/HelloClient.csproj
   ```

## Testing

```bash
# Run tests using .NET CLI
dotnet test HelloUT/HelloUT.csproj
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

3. **.NET Issues**
   ```bash
   # Clean and restore packages
   dotnet clean
   dotnet restore
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| DOTNET_ENVIRONMENT        | .NET environment (Development/Production) | Development  |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Task-based asynchronous programming
- ✅ DI and logging with Microsoft.Extensions libraries
- ✅ Header propagation
- ✅ Environment variable configuration

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow C# coding conventions
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
