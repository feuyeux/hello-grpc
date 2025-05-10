# Docker Build Guide for gRPC Multi-language Project

This directory contains scripts and Dockerfiles for building gRPC server and client images across 12 programming languages. The build system is designed to work on any machine with Docker installed, without requiring local development environments.

## Key Features

- All compilation and building happens within Docker containers
- Multi-stage builds for smaller final images
- Supports 12 programming languages: C++, Rust, Java, Go, C#, Python, Node.js, Dart, Kotlin, Swift, PHP, TypeScript

## Image Naming Convention

- Server images: `feuyeux/grpc_server_<language>:1.0.0`
- Client images: `feuyeux/grpc_client_<language>:1.0.0`

For example: `feuyeux/grpc_server_java:1.0.0`, `feuyeux/grpc_client_go:1.0.0`

## Docker Images

<https://hub.docker.com/repositories/feuyeux>

| No. | Language                    | Base Image                                                     | Server Image                     | Client Image                     |
|:----|:----------------------------|:---------------------------------------------------------------|:---------------------------------|:---------------------------------|
| 1   | [C++](hello-grpc-cpp)        | [debian:12-slim](cpp_grpc.dockerfile)                          | feuyeux/grpc_server_cpp:1.0.0    | feuyeux/grpc_client_cpp:1.0.0    |
| 2   | [Rust](hello-grpc-rust)      | [rust:1.81-alpine3.20](rust_grpc.dockerfile)                   | feuyeux/grpc_server_rust:1.0.0   | feuyeux/grpc_client_rust:1.0.0   |
| 3   | [Java](hello-grpc-java)      | [openjdk:23-jdk-slim](java_grpc.dockerfile)                    | feuyeux/grpc_server_java:1.0.0   | feuyeux/grpc_client_java:1.0.0   |
| 4   | [Go](hello-grpc-go)          | [golang:1.23-alpine](go_grpc.dockerfile)                       | feuyeux/grpc_server_go:1.0.0     | feuyeux/grpc_client_go:1.0.0     |
| 5   | [C#](hello-grpc-csharp)      | [mcr.microsoft.com/dotnet/runtime:8.0](csharp_grpc.dockerfile) | feuyeux/grpc_server_csharp:1.0.0 | feuyeux/grpc_client_csharp:1.0.0 |
| 6   | [Python](hello-grpc-python)  | [python:3.11-slim](python_grpc.dockerfile)                     | feuyeux/grpc_server_python:1.0.0 | feuyeux/grpc_client_python:1.0.0 |
| 7   | [Node.js](hello-grpc-nodejs) | [node:21-alpine](node_grpc.dockerfile)                         | feuyeux/grpc_server_node:1.0.0   | feuyeux/grpc_client_node:1.0.0   |
| 8   | [TypeScript](hello-grpc-ts)  | [node:21-alpine](ts_grpc.dockerfile)                           | feuyeux/grpc_server_ts:1.0.0     | feuyeux/grpc_client_ts:1.0.0     |
| 9   | [Dart](hello-grpc-dart)      | [dart_grpc.dockerfile](dart_grpc.dockerfile)                   | feuyeux/grpc_server_dart:1.0.0   | feuyeux/grpc_client_dart:1.0.0   |
| 10  | [Kotlin](hello-grpc-kotlin)  | [openjdk:21-jdk-slim](kotlin_grpc.dockerfile)                  | feuyeux/grpc_server_kotlin:1.0.0 | feuyeux/grpc_client_kotlin:1.0.0 |
| 11  | [Swift](hello-grpc-swift)    | [swift:6.0.1-slim](swift_grpc.dockerfile)                      | feuyeux/grpc_server_swift:1.0.0  | feuyeux/grpc_client_swift:1.0.0  |
| 12  | [PHP](hello-grpc-php)        | [composer:2.8](php_grpc_base.dockerfile)                       | feuyeux/grpc_server_php:1.0.0    | feuyeux/grpc_client_php:1.0.0    |

## Usage Guide

### 1. Building Images

```sh
# Build images for a specific language
sh build_image.sh --language ${lang} [--component server|client|both]

# Example: Build Java server image
sh build_image.sh --language java --component server
```

### 2. Running Containers

#### Basic Communication

```bash
# Terminal 1: Start the server container
sh run_container.sh --language go --component server
# Or using shorter options:
sh run_container.sh -l go -c server

# Terminal 2: Start the client container
sh run_container.sh --language go --component client
# Or using shorter options:
sh run_container.sh -l go -c client
```

#### Proxy Mode

The Docker containers also support proxy mode, where the server can forward requests to another backend server:

```bash
export server_lang=swift
export proxy_lang=swift
export client_lang=swift

# First, create a custom Docker network for container communication
docker network create grpc_network

# Terminal 1: Start the backend server container
docker run --rm --name "grpc_server_${server_lang}" -p 9996:9996 --network="grpc_network" "feuyeux/grpc_server_${server_lang}:1.0.0"

# Terminal 2: Start the proxy server container 
docker run --rm --name "grpc_proxy_${proxy_lang}" -p 9997:9997 \
  -e GRPC_SERVER_PORT=9997 \
  -e GRPC_HELLO_BACKEND=grpc_server_${server_lang} \
  -e GRPC_HELLO_BACKEND_PORT=9996 \
  --network="grpc_network" \
  "feuyeux/grpc_server_${proxy_lang}:1.0.0"

# Terminal 3: Start the client container connecting to proxy
docker run --rm --name "grpc_client_${client_lang}" \
  -e GRPC_SERVER=grpc_proxy_${proxy_lang} \
  -e GRPC_SERVER_PORT=9997 \
  --network="grpc_network" \
  "feuyeux/grpc_client_${client_lang}:1.0.0"
```

> **Important**: All containers must be on the same Docker network for proper hostname resolution. The example above creates a custom network called `grpc_network` and connects all containers to it.

#### Cross-language Testing with TLS

You can run servers and clients in different languages with TLS to test secure cross-language compatibility:

```bash
# Terminal 1: Start the backend server container with TLS
sh run_container.sh -l java -c server -e "GRPC_HELLO_SECURE=Y"

# Terminal 2: Start the proxy server container with TLS
sh run_container.sh -l go -c server -e "GRPC_SERVER_PORT=9997 GRPC_HELLO_BACKEND=hello-grpc-java GRPC_HELLO_BACKEND_PORT=9996 GRPC_HELLO_SECURE=Y"

# Terminal 3: Start the client container with TLS
sh run_container.sh -l python -c client -e "GRPC_SERVER=hello-grpc-go GRPC_SERVER_PORT=9997 GRPC_HELLO_SECURE=Y"
```

> **Note**: When running with `-s` option, containers are started in separate Docker networks, simulating a distributed environment.

### 3. Pushing Images to Registry

```sh
# Push images for a specific language (e.g., Java)
sh push_image.sh java

# Push all language images
sh push_image.sh
```

## Architecture Overview

The project demonstrates gRPC implementation across multiple programming languages:

- Each language implements the same protobuf-defined services
- All implementations support both server and client roles
- TLS/SSL certificates are included for secure communication
- Multi-stage Docker builds ensure efficient image sizes
- Uniform build and run commands across all languages

## Customization

Each Dockerfile contains three main stages:

1. `build-base`: Contains all necessary tools to compile the application
2. `server`: Contains only what's needed to run the server
3. `client`: Contains only what's needed to run the client

You can modify these Dockerfiles to:

- Use different base images
- Add custom dependencies
- Implement language-specific optimizations
- Change build arguments

## Troubleshooting

- If you encounter network issues, check your Docker network settings
- For build failures, increase Docker resource limits (memory/CPU)
- For language-specific issues, refer to the respective language directory's README
- To diagnose container issues, use `docker logs` to view output
