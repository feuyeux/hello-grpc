# Hello gRPC Java Scripts

This directory contains utility scripts for building, running, and managing the Java gRPC implementation.

## Available Scripts

### Build Scripts

#### `build.sh`
Builds the Java gRPC project using Maven.

**Usage:**
```bash
./build.sh [options]

Options:
  --clean, -c        Clean build artifacts before building
  --test, -t         Run tests after building
  --release, -r      Build in release mode (optimized)
  --verbose, -v      Enable verbose output
  --help, -h         Show help message
```

**Examples:**
```bash
./build.sh                  # Standard build
./build.sh --clean          # Clean and build
./build.sh --test           # Build and run tests
./build.sh --verbose        # Build with detailed output
```

### Server Scripts

#### `server_start.sh`
Starts the gRPC server with various configuration options.

**Usage:**
```bash
./server_start.sh [options]

Options:
  --addr=HOST:PORT          Server address (default: 127.0.0.1:9996)
  --tls                     Enable TLS encryption
  --log=LEVEL              Log level (trace|debug|info|warn|error)
  --profile=PROFILE        Run profile (dev|prod|test)
  --clean                  Clean build before starting
  --skip-build             Skip build step
  --background, -b         Run in background
  --debug                  Enable debug mode (port 5005)
  --verbose, -v            Verbose output
```

**Examples:**
```bash
./server_start.sh                              # Start with defaults
./server_start.sh --addr=0.0.0.0:8080         # Custom address
./server_start.sh --tls                        # Enable TLS
./server_start.sh --background                 # Run in background
./server_start.sh --skip-build --log=debug    # Skip build, debug logging
```

#### `stop_server.sh`
Stops the gRPC server running on a specific port.

**Usage:**
```bash
./stop_server.sh [options]

Options:
  --port=PORT       Port number to check (default: 9996)
  --force, -f       Force kill processes (SIGKILL)
  --verbose, -v     Verbose output
  --help, -h        Show help message
```

**Examples:**
```bash
./stop_server.sh                    # Stop server on port 9996
./stop_server.sh --port=9997       # Stop server on port 9997
./stop_server.sh --force           # Force kill server processes
```

### Client Scripts

#### `client_start.sh`
Starts the gRPC client to connect to a server.

**Usage:**
```bash
./client_start.sh [options]

Options:
  --tls                 Enable TLS communication
  --addr=HOST:PORT      Server address (default: 127.0.0.1:9996)
  --log=LEVEL           Log level (trace|debug|info|warn|error)
  --count=NUMBER        Number of requests to send
  --help, -h            Show help message
```

**Examples:**
```bash
./client_start.sh                              # Connect with defaults
./client_start.sh --addr=localhost:8080       # Custom server address
./client_start.sh --tls                        # Enable TLS
./client_start.sh --count=5                    # Send 5 request iterations
```

### Testing Scripts

#### `test_scripts.sh`
Runs integration tests to verify all scripts work correctly.

**Usage:**
```bash
./test_scripts.sh
```

**Tests:**
- build.sh handles up-to-date projects correctly
- server_start.sh can start in background mode
- Full integration test (server + client) works

### PowerShell Scripts (Windows)

Windows equivalents are available with `.ps1` extension:
- `build.ps1`
- `server_start.ps1`
- `client_start.ps1`

## Common Workflows

### Basic Server-Client Test

```bash
# Terminal 1: Start server
./server_start.sh

# Terminal 2: Run client
./client_start.sh
```

### TLS-Enabled Communication

```bash
# Terminal 1: Start server with TLS
./server_start.sh --tls

# Terminal 2: Run client with TLS
./client_start.sh --tls
```

### Background Server with Cleanup

```bash
# Start server in background
./server_start.sh --background

# Run client
./client_start.sh

# Stop server
./stop_server.sh
```

### Development Mode

```bash
# Start server with debug mode and verbose logging
./server_start.sh --debug --log=debug --verbose

# In another terminal, attach debugger to port 5005
```

### Clean Build and Test

```bash
# Clean build with tests
./build.sh --clean --test

# Start server (skip build since we just built)
./server_start.sh --skip-build

# Run client
./client_start.sh
```

## Environment Variables

Scripts respect the following environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `JAVA_HOME` | Java installation path | Auto-detected |
| `MAVEN_HOME` | Maven installation path | Auto-detected |
| `GRPC_HELLO_SECURE` | Enable TLS (Y/N) | N |
| `GRPC_SERVER` | Server host | localhost |
| `GRPC_SERVER_PORT` | Server port | 9996 |
| `GRPC_LOG_LEVEL` | Log level | info |

## Troubleshooting

### Port Already in Use

```bash
# Stop any server on port 9996
./stop_server.sh

# Or use force mode
./stop_server.sh --force

# Or use the universal kill_port script
../../scripts/kill_port.sh 9996
```

### Java Version Issues

The scripts auto-detect Java installations. If detection fails:

```bash
# Set JAVA_HOME manually
export JAVA_HOME=/path/to/your/java
./server_start.sh
```

### Build Failures

```bash
# Try a clean build
./build.sh --clean --verbose

# Check Maven and Java versions
mvn -version
java -version
```

### Connection Issues

```bash
# Check if server is running
lsof -i :9996

# Check server logs
tail -f ../log/hello-grpc.log

# Try verbose client mode
./client_start.sh --log=debug
```

## Notes

- All scripts include help documentation (`--help`)
- Scripts use consistent color-coded logging
- Error messages are sent to stderr
- Scripts are designed to fail fast with `set -e`
- Background mode creates a PID file for cleanup
