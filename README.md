<!-- markdownlint-disable MD033 MD045 -->

# Hello gRPC 

**Comprehensive gRPC examples and tutorials across 12+ programming languages**

*Learn gRPC with comprehensive tutorials, examples, and best practices for Java, Go, Python, Node.js, Rust, C++, C#, Kotlin, Swift, Dart, PHP, and TypeScript*

---

*A comprehensive collection of gRPC examples and tutorials covering microservices, distributed systems, and modern API development across multiple programming languages.*

[![GitHub stars](https://img.shields.io/github/stars/feuyeux/hello-grpc?style=social)](https://github.com/feuyeux/hello-grpc/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/feuyeux/hello-grpc?style=social)](https://github.com/feuyeux/hello-grpc/network/members)
[![GitHub issues](https://img.shields.io/github/issues/feuyeux/hello-grpc)](https://github.com/feuyeux/hello-grpc/issues)
[![GitHub license](https://img.shields.io/github/license/feuyeux/hello-grpc)](https://github.com/feuyeux/hello-grpc/blob/main/LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/feuyeux/grpc_server_java)](https://hub.docker.com/u/feuyeux)

This repository demonstrates gRPC implementations across 12+ programming languages, featuring production-ready examples with Docker containers, Kubernetes deployment configurations, and service mesh integration patterns.



## Supported Programming Languages & Frameworks

**Complete gRPC implementations** with identical functionality across all major programming languages:

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

## gRPC Architecture & Communication Patterns

![gRPC Architecture Diagram](doc/diagram/hello-grpc.svg)

### Communication Models

1. **Unary RPC** - Simple request-response (like HTTP REST)
2. **Server Streaming** - One request, multiple responses
3. **Client Streaming** - Multiple requests, one response  
4. **Bidirectional Streaming** - Both sides send multiple messages independently

### Architecture Patterns

- **Microservices** - Service-to-service communication
- **API Gateway** - HTTP/REST to gRPC transcoding
- **Load Balancing** - Client-side and server-side strategies
- **Service Discovery** - Consul, etcd, Kubernetes DNS integration
- **Resilience** - Circuit breakers, retries, fault tolerance

## Feature Implementation Status

### Implementation Matrix

| Language   | Headers | TLS      | Proxy | [Docker][39] | Build System             | Unit Testing            | Logging         |
|:-----------|:--------|:---------|:------|:------------|:-------------------------|:------------------------|:----------------|
| Java       | ✅      | ✅ mTLS  | ✅    | ✅          | [Maven][1]               | [JUnit 5][2]            | [Log4j2][3]     |
| Go         | ✅      | ✅ mTLS  | ✅    | ✅          | [Go Modules][40]         | [Go Testing][41]        | [Logrus][5]     |
| Node.js    | ✅      | ✅ TLS   | ✅    | ✅          | [npm][7]                 | [Mocha][8]              | [Winston][9]    |
| TypeScript | ✅      | ✅ TLS   | ✅    | ✅          | [Yarn][28] & [TSC][29]   | [Jest][42]              | [Winston][9]    |
| Python     | ✅      | ✅ mTLS  | ✅    | ✅          | [pip][11]                | [unittest][43]          | [logging][44]   |
| Rust       | ✅      | ✅ mTLS  | ✅    | ✅          | [Cargo][13]              | [Rust Test][45]         | [log4rs][14]    |
| C++        | ✅      | ✅ mTLS  | ✅    | ✅          | [Bazel][37]/[CMake][16]  | [Catch2][24]            | [glog][17]      |
| C#         | ✅      | ✅ mTLS  | ✅    | ✅          | [NuGet][18]              | [NUnit][30]             | [log4net][19]   |
| Kotlin     | ✅      | ✅ mTLS  | ✅    | ✅          | [Gradle][21]             | [JUnit 5][2]            | [Log4j2][3]     |
| Swift      | ✅      | ✅ TLS   | ✅    | ✅          | [SPM][22]                | [Swift Testing][38]     | [swift-log][23] |
| Dart       | ✅      | ✅ TLS   | ✅    | ✅          | [Pub][25]                | [Test][27]              | [Logger][26]    |
| PHP        | ✅      | ✅ mTLS  | ✅    | ✅          | [Composer][34]      | [PHPUnit][35]           | [Monolog][36]   |

## Project Statistics

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
