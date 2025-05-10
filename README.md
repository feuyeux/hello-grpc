<!-- markdownlint-disable MD033 MD045 -->

# Hello gRPC

A comprehensive collection of gRPC examples in multiple programming languages demonstrating:

- Four gRPC communication models (unary, client streaming, server streaming, bidirectional streaming)
- TLS secure connections
- Proxy & propagation patterns
- Containerization with Docker
- Kubernetes deployment
- Service mesh integration

## 🌟 Supported Languages & Tools

| No. | Language                     | gRPC Library                                                    | Recommended IDE  |
|:----|:-----------------------------|:----------------------------------------------------------------|:-----------------|
| 1   | [C++](hello-grpc-cpp)        | **[gRPC](https://github.com/grpc/grpc/releases)**               | [CLion][15]      |
| 2   | [Rust](hello-grpc-rust)      | **[Tonic](https://lib.rs/crates/tonic/versions)**               | [RustRover][31]  |
| 3   | [Java](hello-grpc-java)      | **[gRPC-Java](https://github.com/grpc/grpc-java/releases)**     | [IntelliJ IDEA][4]        |
| 4   | [Go](hello-grpc-go)          | **[gRPC-Go](https://github.com/grpc/grpc-go/releases)**         | [GoLand][6]      |
| 5   | [C#](hello-grpc-csharp)      | **[gRPC-dotnet](https://github.com/grpc/grpc-dotnet/releases)** | [Rider][20]      |
| 6   | [Python](hello-grpc-python)  | **[grpcio](https://pypi.org/project/grpcio-tools)**             | [PyCharm][12]    |
| 7   | [Node.js](hello-grpc-nodejs) | **[@grpc/grpc-js](https://www.npmjs.com/package/@grpc/grpc-js)**      | [WebStorm][10]   |
| 8   | [TypeScript](hello-grpc-ts)  | **[gRPC-js](https://www.npmjs.com/package/@grpc/grpc-js)**      | [WebStorm][10]   |
| 9   | [Dart](hello-grpc-dart)      | **[grpc-dart](https://pub.dev/packages/grpc)**                  | [PyCharm][12]    |
| 10  | [Kotlin](hello-grpc-kotlin)  | **[gRPC-Kotlin](https://github.com/grpc/grpc-kotlin/releases)** | [IntelliJ IDEA][4]        |
| 11  | [Swift](hello-grpc-swift)    | **[gRPC-Swift](https://github.com/grpc/grpc-swift/releases)**   | [Xcode][32]    |
| 12  | [PHP](hello-grpc-php)        | **[gRPC-PHP](https://packagist.org/packages/grpc/grpc)**        | [PhpStorm][33]   |

## 📊 Architecture Overview

![grpc_diagram](diagram/hello-grpc.svg)

## 🔍 Feature Implementation Status

### Core gRPC Communication Models & Features

| Language   | Four Models | Collection | Sleep | Random | Timestamp | UUID | Env |
|:-----------|:------------|:-----------|:------|:-------|:----------|:-----|:----|
| Java       | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Go         | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Node.js    | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| TypeScript | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Python     | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Rust       | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| C++        | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| C#         | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Kotlin     | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Swift      | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| Dart       | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |
| PHP        | ✅          | ✅         | ✅    | ✅     | ✅        | ✅   | ✅  |

### Advanced Features & Development Tools

| Language   | Headers | TLS | Proxy | [Docker][39] | Build System             | Unit Testing            | Logging         |
|:-----------|:--------|:----|:------|:------------|:-------------------------|:------------------------|:----------------|
| Java       | ✅      | ✅  | ✅    | ✅          | [Maven][1]               | [JUnit 5][2]            | [Log4j2][3]     |
| Go         | ✅      | ✅  | ✅    | ✅          | [Go Modules][40]         | [Go Testing][41]        | [Logrus][5]     |
| Node.js    | ✅      | ⚠️  | ✅    | ✅          | [npm][7]                 | [Mocha][8]              | [Winston][9]    |
| TypeScript | ✅      | ⚠️  | ✅    | ✅          | [Yarn][28] & [TSC][29]   | [Jest][42]              | [Winston][9]    |
| Python     | ✅      | ✅  | ✅    | ✅          | [pip][11]                | [unittest][43]          | [logging][44]   |
| Rust       | ✅      | ✅  | ✅    | ✅          | [Cargo][13]              | [Rust Test][45]         | [log4rs][14]    |
| C++        | ✅      | ✅  | ✅    | ✅          | [Bazel][37]/[CMake][16]  | [Catch2][24]            | [glog][17]      |
| C#         | ✅      | ✅  | ✅    | ✅          | [NuGet][18]              | [NUnit][30]             | [log4net][19]   |
| Kotlin     | ✅      | ✅  | ✅    | ✅          | [Gradle][21]             | [JUnit 5][2]            | [Log4j2][3]     |
| Swift      | ✅      | ✅  | ⚠️    | ✅          | [SPM][22]                | [Swift Testing][38]     | [swift-log][23] |
| Dart       | ✅      | 🚧  | 🚧    | ✅          | [Pub][25]                | [Test][27]              | [Logger][26]    |
| PHP        | ✅      | 🚧  | 🚧    | ✅          | [Composer][34]           | [PHPUnit][35]           | [Monolog][36]   |

**Legend:**

- ✅ Implemented and working
- ❌ Not implemented
- ⚠️ Implemented with known issues
- 🚧 Implementation in progress

## 🚀 Getting Started

### Environment Variables

| Variable                  | Description                                |
|:--------------------------|:-------------------------------------------|
| `GRPC_SERVER`             | gRPC server host on client side            |
| `GRPC_SERVER_PORT`        | gRPC server port on client side            |
| `GRPC_HELLO_BACKEND`      | Next gRPC server host on server side       |
| `GRPC_HELLO_BACKEND_PORT` | Next gRPC server port on server side       |
| `GRPC_HELLO_SECURE`       | Set to `Y` to enable TLS on both sides     |

### Multi-Language Container Example

The following demonstrates a chain of gRPC calls across multiple language services:

**client(kotlin)** → **server1(java)** → **server2(golang)** → **server3(rust)**

```bash
# First, create a custom Docker network for container communication
docker network create grpc_network

# server3(rust):8883
docker run --rm --name grpc_server_rust -d \
 -p 8883:8883 \
 -e GRPC_SERVER_PORT=8883 \
 --network="grpc_network" \
 feuyeux/grpc_server_rust:1.0.0

# server2(golang):8882
docker run --rm --name grpc_server_go -d \
 -p 8882:8882 \
 -e GRPC_SERVER_PORT=8882 \
 -e GRPC_HELLO_BACKEND=grpc_server_rust \
 -e GRPC_HELLO_BACKEND_PORT=8883 \
 --network="grpc_network" \
 feuyeux/grpc_server_go:1.0.0

# server1(java):8881
docker run --rm --name grpc_server_java -d \
 -p 8881:8881 \
 -e GRPC_SERVER_PORT=8881 \
 -e GRPC_HELLO_BACKEND=grpc_server_go \
 -e GRPC_HELLO_BACKEND_PORT=8882 \
 --network="grpc_network" \
 feuyeux/grpc_server_java:1.0.0

# client(kotlin)
docker run --rm --name grpc_client_kotlin \
 -e GRPC_SERVER=grpc_server_java \
 -e GRPC_SERVER_PORT=8881 \
 --network="grpc_network" \
 feuyeux/grpc_client_kotlin:1.0.0
```

> **Important**: All containers must be on the same Docker network for proper hostname resolution. The example above creates a custom network called `grpc_network` and connects all containers to it.

### Advanced Deployment Options

- [Building and publishing Docker images](docker/README.md)
- [Kubernetes deployment](k8s/kube)
- [Service mesh integration](k8s/mesh)
- [OpenTracing support](k8s/tracing)
- [HTTP-to-gRPC transcoding](k8s/transcoder)

### Debugging

Enable gRPC debugging with:

```bash
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all
```

## 🔖 Recommended Resources

- [Awesome gRPC](https://github.com/grpc-ecosystem/awesome-grpc)
- [gRPC Gateway](https://github.com/grpc-ecosystem/grpc-gateway)
- [gRPC Web](https://github.com/grpc/grpc-web)
- [Protocol Buffers Language Guide](https://protobuf.dev/programming-guides/proto3/)
- [gRPC Best Practices](https://grpc.io/docs/guides/best-practices/)

## ⭐ Project Stats

[![Star History Chart](https://api.star-history.com/svg?repos=feuyeux/hello-grpc&type=Date)](https://star-history.com/#feuyeux/hello-grpc&Date)

[1]: <https://maven.apache.org/>
[2]: <https://junit.org/junit5/>
[3]: <https://logging.apache.org/log4j>
[4]: <https://www.jetbrains.com/idea/>
[5]: <https://github.com/sirupsen/logrus>
[6]: <https://www.jetbrains.com/go/>
[7]: <https://www.npmjs.com/>
[8]: <https://www.npmjs.com/package/mocha>
[9]: <https://www.npmjs.com/package/winston>
[10]: <https://www.jetbrains.com/webstorm/>
[11]: <https://pypi.org/project/pip/>
[12]: <https://www.jetbrains.com/pycharm/>
[13]: <https://doc.rust-lang.org/cargo/>
[14]: <https://docs.rs/log4rs>
[15]: <https://www.jetbrains.com/clion/>
[16]: <https://cmake.org/>
[17]: <https://github.com/google/glog>
[18]: <https://www.nuget.org/>
[19]: <https://logging.apache.org/log>
[20]: <https://www.jetbrains.com/rider/>
[21]: <https://gradle.org/>
[22]: <https://www.swift.org/package-manager/>
[23]: <https://github.com/apple/swift-log>
[24]: <https://github.com/catchorg/Catch2>
[25]: <https://dart.dev/guides/packages>
[26]: <https://pub.dev/packages/logger>
[27]: <https://pub.dev/packages/test>
[28]: <https://yarnpkg.com/>
[29]: <https://www.typescriptlang.org/docs/handbook/compiler-options.html>
[30]: <https://nunit.org/>
[31]: <https://www.jetbrains.com/rust/>
[32]: <https://developer.apple.com/xcode/>
[33]: <https://www.jetbrains.com/phpstorm/>
[34]: <https://getcomposer.org/>
[35]: <https://phpunit.de/>
[36]: <https://github.com/Seldaek/monolog>
[37]: <https://bazel.build/>
[38]: <https://github.com/apple/swift-testing>
[39]: <https://www.docker.com/>
[40]: <https://github.com/golang/go/wiki/Modules>
[41]: <https://golang.org/pkg/testing/>
[42]: <https://jestjs.io/>
[43]: <https://docs.python.org/3/library/unittest.html>
[44]: <https://docs.python.org/3/library/logging.html>
[45]: <https://doc.rust-lang.org/book/ch11-00-testing.html>
