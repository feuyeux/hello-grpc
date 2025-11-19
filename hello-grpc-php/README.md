# PHP gRPC Implementation

This project implements a gRPC client and server using PHP, demonstrating four communication patterns:
1. Unary RPC
2. Server Streaming RPC
3. Client Streaming RPC
4. Bidirectional Streaming RPC

## Prerequisites

| Component          | Version  | Notes                             |
|--------------------|----------|-----------------------------------|
| PHP                | 8.4.8    | PHP runtime                       |
| Build Tool         | Composer | PHP package manager               |
| gRPC               | 1.57.0+  | grpc/grpc extension               |
| Protocol Buffers   | 4.0.0+   | google/protobuf                   |
| protoc             | Latest   | Protocol Buffers compiler         |
| PHP gRPC Extension | Latest   | pecl install grpc                 |

## Building the Project

### 1. Install PHP gRPC Extension

```bash
# Install PHP gRPC extension
pecl install grpc

# Verify installation
php -i | grep grpc

php --ini

export PHP_HOME=/opt/homebrew/etc/php/8.4
code $PHP_HOME/php.ini

extension=grpc.so

# windows
extension=./php_grpc.dll
extension=./php_protobuf.dll
```

### 2. Install Dependencies

```bash
# Install PHP dependencies
composer install
```

### 3. Generate gRPC Code from Proto Files

```bash
# Generate PHP code from proto files
mkdir -p generated
protoc --php_out=generated \
  --grpc_php_plugin_out=generated \
  --proto_path=../proto \
  ../proto/landing.proto
```

## Running the Application

### Basic Communication

```bash
# Terminal 1: Start the server
php -d extension=grpc.so hello_server.php
php -d extension=grpc.so hello_client.php

# Terminal 2: Start the client
php -d extension=php_grpc.dll hello_server.php
php -d extension=php_grpc.dll hello_client.php
```

### Proxy Mode

PHP implementation supports proxy mode, where the server can forward requests to another backend server:

```bash
# Terminal 1: Start the backend server
php server.php

# Terminal 2: Start the proxy server
GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 php server.php

# Terminal 3: Start the client
GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 php client.php
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
   GRPC_HELLO_SECURE=Y php server.php
   
   # Terminal 2: Start the client with TLS
   GRPC_HELLO_SECURE=Y php client.php
   ```

3. **TLS with Proxy**

   ```bash
   # Terminal 1: Start the backend server with TLS
   GRPC_HELLO_SECURE=Y php server.php
   
   # Terminal 2: Start the proxy server with TLS
   GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=localhost GRPC_HELLO_BACKEND_PORT=9996 \
   GRPC_HELLO_SECURE=Y php server.php
   
   # Terminal 3: Start the client with TLS
   GRPC_SERVER=localhost GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y php client.php
   ```

## Testing

This project uses PHPUnit for standardized testing. All tests are located in the `tests/` directory.

```bash
# Run all tests with PHPUnit
./vendor/bin/phpunit tests/

# Run a specific test
./vendor/bin/phpunit tests/VersionTest.php
./vendor/bin/phpunit tests/HelloTest.php
```

### Test Structure

- **VersionTest**: Tests the gRPC version retrieval functionality
- **HelloTest**: Tests basic string manipulation utilities

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

3. **PHP gRPC Extension Issues**
   ```bash
   # Verify PHP gRPC extension is installed
   php -m | grep grpc
   
   # Check PHP error log
   tail -f /var/log/php-fpm/error.log
   ```

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
| PHP_LOG_LEVEL             | PHP logging level                         | INFO         |

## Features

- ✅ Four gRPC communication models
- ✅ TLS secure communication
- ✅ Proxy functionality
- ✅ Docker compatibility
- ✅ Composer package management
- ✅ PSR-3 compliant logging
- ✅ Header propagation
- ✅ Environment variable configuration
- ✅ Standardized version implementation
- ✅ PHPUnit test coverage

## Implementation Standards

This PHP implementation follows standard practices for multi-language gRPC projects:

1. **Version Implementation**: The `VersionUtils` class provides a standardized way to retrieve the gRPC version using the `getVersion()` method, which follows the format `grpc.version=X.Y.Z`.

2. **Test Organization**: All test files are located in the `tests/` directory and follow PHPUnit standards.

3. **Common Utilities**: Common functionality is encapsulated in utility classes under the `common/utils/` directory.

4. **Namespace Structure**: The codebase uses PSR-4 compliant namespaces:
   - `Common\Utils` for utility classes
   - `Tests` for test classes

5. **Logging Standards**: Uses Monolog for structured logging, compatible with other language implementations.

## Contributor Notes

When modifying or extending this implementation, please:
1. Follow PSR-12 coding standards
2. Add appropriate tests for new functionality in the `tests/` directory
3. For utility functions, create classes in `common/utils/` following the established pattern
4. Update documentation as needed
5. Ensure compatibility with the multi-language chaining demonstrated in the root README

## Improved Scripts and Logging

The implementation now includes improved scripts for running the server and client with better logging:

### Updated Scripts

- `server_start.sh`: Start the gRPC server with clean output
- `silent_run.sh`: Run the server with filtered warning messages
- `client_start.sh`: Start the gRPC client with clean output
- `client_run.sh`: Run the client with filtered warning messages

### Monolog Integration

This implementation uses Monolog for structured logging:

- Logs are stored in the `log/` directory
- Server logs: `hello-grpc-*.log`
- Client logs: `hello-client-*.log`
- PHP error logs: `php_errors.log` and `php_client_errors.log`

### Running with Options

```bash
# Start the server
./server_start.sh

# Run the client with options
./client_start.sh --data=1 --meta="hello"

# Run client with streaming
./client_start.sh --stream=server-streaming
./client_start.sh --stream=client-streaming
./client_start.sh --stream=bidirectional
```

## Project Structure

```
hello-grpc-php/
├── common/                 # Common code shared between client and server
│   ├── msg/                # Generated message classes from protobuf
│   ├── svc/                # Generated service stubs from protobuf
│   └── utils/              # Utility classes
│       ├── StringUtils.php # String manipulation utilities
│       └── VersionUtils.php # gRPC version utilities
├── conn/                   # Connection configuration
│   └── Connection.php      # Connection settings and management
├── log/                    # Log files directory
├── tests/                  # PHPUnit test files
│   ├── HelloTest.php       # Basic string tests
│   └── VersionTest.php     # gRPC version tests
├── vendor/                 # Composer dependencies
├── phpunit.xml             # PHPUnit configuration
├── composer.json           # Composer package definition
├── hello_client.php        # Client implementation
├── hello_server.php        # Server implementation
├── LandingService.php      # Service implementation
├── client_start.sh         # Script to start the client
├── server_start.sh         # Script to start the server
├── build.sh                # Script to build the project
└── README.md               # This documentation
```
