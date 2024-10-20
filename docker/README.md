# Docker Images

<https://hub.docker.com/repositories/feuyeux>

| No. | Lang                         | Base  Image                                                    | Server                           | Client                           |
|:----|:-----------------------------|:---------------------------------------------------------------|:---------------------------------|:---------------------------------|
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

## Build

```sh
sh ${lang}_build.sh
```

## Run

### server

```sh
sh ${lang}_run_server.sh
```

### client

```sh
sh ${lang}_run_client.sh
```

### cross

```sh
sh cross_run_client.sh
```

## Push

```sh
sh ${lang}_push.sh
```
