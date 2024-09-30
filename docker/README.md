# Docker Images

<https://hub.docker.com/repositories/feuyeux>

| No. | Lang                         | Base  Image                                                    | Server                           | Client                           |
|:----|:-----------------------------|:---------------------------------------------------------------|:---------------------------------|:---------------------------------|
| 1   | [C++](hello-grpc-cpp)        |                                                                | feuyeux/grpc_server_cpp:1.0.0    | feuyeux/grpc_client_cpp:1.0.0    |
| 2   | [Rust](hello-grpc-rust)      |                                                                | feuyeux/grpc_server_rust:1.0.0   | feuyeux/grpc_client_rust:1.0.0   |
| 3   | [Java](hello-grpc-java)      | [openjdk:21-jdk-slim](java_grpc.dockerfile)                                                               | feuyeux/grpc_server_java:1.0.0   | feuyeux/grpc_client_java:1.0.0   |
| 4   | [Go](hello-grpc-go)          | [golang:1.23-alpine](go_grpc.dockerfile)                       | feuyeux/grpc_server_go:1.0.0     | feuyeux/grpc_client_go:1.0.0     |
| 5   | [C#](hello-grpc-csharp)      | [mcr.microsoft.com/dotnet/runtime:8.0](csharp_grpc.dockerfile) | feuyeux/grpc_server_csharp:1.0.0 | feuyeux/grpc_client_csharp:1.0.0 |
| 6   | [Python](hello-grpc-python)  |                                                                | feuyeux/grpc_server_python:1.0.0 | feuyeux/grpc_client_python:1.0.0 |
| 7   | [Node.js](hello-grpc-nodejs) |                                                                | feuyeux/grpc_server_nodejs:1.0.0 | feuyeux/grpc_client_nodejs:1.0.0 |
| 8   | [Dart](hello-grpc-dart)      |                                                                | feuyeux/grpc_server_dart:1.0.0   | feuyeux/grpc_client_dart:1.0.0   |
| 9   | [Kotlin](hello-grpc-kotlin)  |  [openjdk:21-jdk-slim](kotlin_grpc.dockerfile)                                                           | feuyeux/grpc_server_kotlin:1.0.0 | feuyeux/grpc_client_kotlin:1.0.0 |
| 10  | [Swift](hello-grpc-swift)    |                                                                | feuyeux/grpc_server_swift:1.0.0  | feuyeux/grpc_client_swift:1.0.0  |
| 11  | [PHP](hello-grpc-php)        |                                                                | feuyeux/grpc_server_php:1.0.0    | feuyeux/grpc_client_php:1.0.0    |
| 12  | [TypeScript](hello-grpc-ts)  |                                                                | feuyeux/grpc_server_ts:1.0.0     | feuyeux/grpc_client_ts:1.0.0     |

## Build

```sh
sh ${lang}_build.sh
```

## Run

```sh
sh ${lang}_run_server.sh
```

```sh
sh ${lang}_run_client.sh
```

## Push

```sh
sh ${lang}_push.sh
```
