# Python gRPC Implementation

This project implements a gRPC client and server using Python, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

| Component          | Version | Notes                             |
|--------------------|---------|-----------------------------------|
| Python             | 3.13.3  | Python runtime                    |
| Build Tool         | pip     | Python package manager            |
| gRPC               | 1.76.0  | grpcio-tools                      |
| Protocol Buffers   | 6.33.1  | protobuf                          |
| protoc             | Auto    | Included in grpcio-tools          |

## Building the Project

### 1. Set Up Python Environment

```bash
# Optional: Configure PyPI mirror for faster downloads in China
# 1. Aliyun's mirror of the Python Package Index (PyPI)
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple
# 2. Tsinghua University's mirror of PyPI
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
# 3. University of Science and Technology of China's mirror of PyPI
pip config set global.index-url https://pypi.mirrors.ustc.edu.cn/simple

# Create a virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install required packages
pip install -r requirements.txt
```

**Note**: The start scripts (`server_start.sh` and `client_start.sh`) automatically detect and activate the virtual environment if it exists in the current directory or parent directory.

### 2. Generate gRPC Code from Proto Files

```bash
# Generate Python code from proto files
python -m grpc_tools.protoc \
  -I../proto \
  --python_out=. \
  --grpc_python_out=. \
  ../proto/landing.proto
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
python server.py

# Terminal 2: Start the client
python client.py
```

### Proxy Mode

Python implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
python server.py

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 python server.py

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 python client.py
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

   Using the start scripts with `--tls` flag (recommended):
   ```bash
   # Terminal 1: Start the server with TLS
   bash server_start.sh --tls
   
   # Terminal 2: Start the client with TLS
   bash client_start.sh --tls
   ```

   Or using environment variables directly:
   ```bash
   # Terminal 1: Start the server with TLS
   GRPC_HELLO_SECURE=Y python server/protoServer.py
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y python client/protoClient.py
   ```
   
   **Note**: The start scripts automatically:
   - Activate virtual environment if available
   - Set proper certificate paths based on OS
   - Verify certificate files exist
   - Configure TLS environment variables

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y python server.py
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y python server.py
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y python client.py
   ```

## Utility Functions

### gRPC Version Detection

The project includes a utility function to retrieve the gRPC version:

```python
from conn.utils import get_version

# Get gRPC version
version = get_version()  # Returns "grpc.version=X.Y.Z", e.g. "grpc.version=1.71.0"
print(version)
```

This function is useful for diagnostic purposes and compatibility checks between different gRPC implementations.

## Testing

```bash
# Run all tests
python -m unittest discover tests/

# Run specific test file
python -m unittest tests/test_utils.py
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
   tail -f log/hello_grpc.log
   ```

3. **Python Environment Issues**
   ```bash
   # Verify virtual environment is active
   which python  # Should point to your venv
   
   # Reinstall dependencies 
   pip install --upgrade -r requirements.txt
   ```

## Environment Variables

| Environment Variable       | Description                               | Default Value |
|---------------------------|-------------------------------------------|--------------|
| GRPC_HELLO_SECURE         | Enable TLS encryption                     | N            |
| GRPC_SERVER               | Server address (client side)              | localhost    |
| GRPC_SERVER_PORT          | Server port (client side)                 | 9996         |
| GRPC_HELLO_BACKEND        | Backend server address (proxy mode)       | N/A          |
| GRPC_HELLO_BACKEND_PORT   | Backend server port (proxy mode)          | Same as GRPC_SERVER_PORT |
| PYTHONPATH                | Python module search path                 | N/A          |
| PYTHON_LOG_LEVEL          | Python logging level                      | INFO         |
| DEBUG                     | Enable debug mode                         | False        |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Async implementation with asyncio
- ✅ Structured logging
- ✅ Header propagation
- ✅ Environment variable configuration
- ✅ gRPC version detection utility

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow PEP 8 style guidelines
2. Add appropriate tests for new functionality
3. Update documentation as needed
4. Ensure compatibility with the multi-language chaining demonstrated in the root README
