# Hello gRPC

![build tools](diagram/build_tools.png)

Simple server and client examples showcasing gRPC features(including proxy and propagate, running in containers and kubernetes) with:

| No. | Lang                                                       | Lib             | IDE             |
|:----|:-----------------------------------------------------------|:----------------|:----------------|
| 1   | [C++](hello-grpc-cpp)                                      | **grpc**        | [CLion][15]     |
| 2   | [Rust](hello-grpc-rust)                                    | **tonic**       | [RustRover][31] |
| 3   | [Java](hello-grpc-java)                                    | **grpc-java**   | [IDEA][4]       |
| 4   | [Go](hello-grpc-go)                                        | **grpc-go**     | [GoLand][6]     |
| 5   | [C#](hello-grpc-csharp)                                    | **grpc-dotnet** | [Rider][20]     |
| 6   | [Python](hello-grpc-python)                                | **grpcio**      | [PyCharm][12]   |
| 7   | [Node.js](hello-grpc-nodejs) / [TypeScript](hello-grpc-ts) | **grpc-js**     | [WebStorm][10]  |
| 8   | [Dart](hello-grpc-dart)                                    | **grpc-dart**   | [PyCharm][12]   |
| 9   | [Kotlin](hello-grpc-kotlin)                                | **grpc-kotlin** | [IDEA][4]       |
| 10  | [Swift](hello-grpc-swift)                                  | **grpc-swift**  | [Xcode][32]     |
| 11  | [PHP](hello-grpc-php)                                      | **grpc-php**    | [PhpStorm][33]  |

## :coffee: What is ...

![grpc_diagram](diagram/hello-grpc.svg)

|            | 4 MODELS | Collection | Sleep | Random | Timestamp | UUID | Env |
|:-----------|:---------|:-----------|:------|:-------|:----------|:-----|:----|
| java       | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| go         | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| nodejs     | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| typescript | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| python     | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| rust       | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| c++        | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| c#         | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| kotlin     | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| swift      | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| dart       | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍎   |
| php        | 🍎        | 🍎          | 🍎     | 🍎      | 🍎         | 🍎    | 🍏   |

|            | Header | TLS | Proxy | Docker | Build                | UT           | LOG             |
|:-----------|:-------|:----|:------|:-------|:---------------------|:-------------|:----------------|
| java       | 🍎      | 🍎   | 🍎     | 🍎      | [maven][1]           | [junit5][2]  | [log4j2][3]     |
| go         | 🍎      | 🍎   | 🍎     | 🍎      | (mod)                | (testing)    | [logrus][5]     |
| nodejs     | 🍎      | 🥑   | 🍎     | 🍎      | [npm][7]             | [mocha][8]   | [winston][9]    |
| typescript | 🍎      | 🍏   | 🍏     | 🍏      | [yarn][28]&[tsc][29] |              | [winston][9]    |
| python     | 🍎      | 🍎   | 🍎     | 🍎      | [pip][11]            | (unittest)   | (logging)       |
| rust       | 🍎      | 🍎   | 🍎     | 🍎      | [cargo][13]          | (test)       | [log4rs][14]    |
| c++        | 🍎      | 🍎   | 🍎     | 🍎      | [cmake][16]          | [Catch2][24] | [glog][17]      |
| c#         | 🍎      | 🍎   | 🍎     | 🍎      | [nuget][18]          | [NUnit][30]  | [log4net][19]   |
| kotlin     | 🍎      | 🍎   | 🍎     | 🍎      | [gradle][21]         | [junit5][2]  | [log4j2][3]     |
| swift      | 🍎      | 🍏   | 🍏     | 🍏      | [spm][22]            | (XCTest)     | [swift-log][23] |
| dart       | 🍎      | 🍏   | 🍏     | 🍏      | [pub][25]            | [test][27]   | [logger][26]    |
| php        | 🍏      | 🍏   | 🍏     | 🍏      | [composer][34]       | 🍏            | 🍏               |

> 🍎 `:apple:` done 
> 🍏 `:green_apple:` unimplemented
> 🥑 `:avocado:` known issues

**Docker-Mesh-Kube**

- [build and publish docker image](docker/README.md)
- [running on kube](k8s/kube)
- [running above service mesh](k8s/mesh)
- [support open tracing](k8s/tracing)
- [transcoder(Http2gRPC)](k8s/transcoder)

## :coffee: How to use ...

### 1 Envs

- `GRPC_SERVER`: grpc server host on client side.
- `GRPC_SERVER_PORT`: grpc server port on client side.
- `GRPC_HELLO_BACKEND`: next grpc server host on server side.
- `GRPC_HELLO_BACKEND_PORT`:next grpc server port on server side.
- `GRPC_HELLO_SECURE`: set it as `Y` when you want to use `TLS` on both sides.

### 2 Containers

Running in containers
`client(kotlin)` -`[tls]:8881`-> `server1(java)` -`[tls]:8882`-> `server2(golang)` -`[tls]:8883`-> `server3(rust)`

```bash
# server3(golang):8883
docker run --rm --name grpc_server_go -d \
 -p 8883:8883 \
 -e GRPC_SERVER_PORT=8883 \
 feuyeux/grpc_server_rust:1.0.0

# server2(rust):8882
docker run --rm --name grpc_server_rust -d \
 -p 8882:8882 \
 -e GRPC_SERVER_PORT=8882 \
 -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
 -e GRPC_HELLO_BACKEND_PORT=8883 \
 feuyeux/grpc_server_go:1.0.0

# server1(java):8881
docker run --rm --name grpc_server_java -d \
 -p 8881:8881 \
 -e GRPC_SERVER_PORT=8881 \
 -e GRPC_HELLO_BACKEND=$(ipconfig getifaddr en0) \
 -e GRPC_HELLO_BACKEND_PORT=8882 \
 feuyeux/grpc_server_java:1.0.0

# client(kotlin)
docker run --rm --name grpc_client_kotlin \
 -e GRPC_SERVER=$(ipconfig getifaddr en0) \
 -e GRPC_SERVER_PORT=8881 \
 feuyeux/grpc_client_kotlin:1.0.0
```

### 3 Logs

Enable gRpc Debugging

```bash
export GRPC_VERBOSITY=DEBUG
export GRPC_TRACE=all
```

## :coffee: Recommend

- <https://github.com/grpc-ecosystem/awesome-grpc>
- <https://github.com/grpc-ecosystem/grpc-gateway>
- <https://github.com/grpc/grpc-web>

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
[31]: <https://www.jetbrains.com/rustrover/>
[32]: <https://xcodereleases.com/>
[33]: <https://www.jetbrains.com/phpstorm/>
[34]: <https://getcomposer.org/>