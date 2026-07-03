# Repository Guidelines

## Project Structure

This repository contains matching gRPC examples across multiple languages. Shared protobuf definitions live in `proto/`.

`proto_bk/landing2.proto` is a separate gateway-oriented contract variant with `google.api` HTTP annotations for gRPC-JSON gateway experiments only. It is not a backup of `proto/landing.proto` and must not be used by the language implementations.

Each implementation is isolated in a `hello-grpc-*` directory:

| Language | Directory |
|---|---|
| C++ | `hello-grpc-cpp/` |
| C# | `hello-grpc-csharp/` |
| Dart | `hello-grpc-dart/` |
| Go | `hello-grpc-go/` |
| Java | `hello-grpc-java/` |
| Kotlin | `hello-grpc-kotlin/` |
| Node.js | `hello-grpc-nodejs/` |
| PHP | `hello-grpc-php/` |
| Python | `hello-grpc-python/` |
| Rust | `hello-grpc-rust/` |
| Swift | `hello-grpc-swift/` |
| TypeScript | `hello-grpc-ts/` |

Docker assets are in `docker/`. Kubernetes, proxy, TLS, mesh, and tracing examples are under `scripts/`. Diagrams and background notes are in `doc/`.

## gRPC And Protobuf Versions

Treat this table as the project version baseline. When changing a protobuf or gRPC version, update the language manifest and this section in the same change.

| Language | Directory | Protobuf version | gRPC version | Codegen / related packages | Version source |
|---|---|---|---|---|---|
| C++ | `hello-grpc-cpp/` | `protobuf 27.2` | `grpc 1.66.0` | `rules_proto 6.0.2`; `//protos:system_protoc` copies `D:\zoo\bin\protoc27.2.exe` | `MODULE.bazel`, `protos/BUILD.bazel` |
| C# | `hello-grpc-csharp/` | `Google.Protobuf 3.35.1` | `Grpc.* 2.80.0` | `Grpc.Tools 2.80.0`; server health/reflection packages also `2.80.0` | `Common/Common.csproj`, `HelloServer/HelloServer.csproj`, `HelloClient/HelloClient.csproj` |
| Dart | `hello-grpc-dart/` | Declared `protobuf ^5.1.0`; resolved `5.1.0` | Declared `grpc ^4.0.1`; resolved `4.3.1` | Generated Dart protobuf files are committed under `lib/common/` | `pubspec.yaml`, `pubspec.lock` |
| Go | `hello-grpc-go/` | `google.golang.org/protobuf v1.36.11` | `google.golang.org/grpc v1.81.1` | Code generation tools are not pinned in `go.mod`; do not infer tool versions from runtime modules | `go.mod` |
| Java | `hello-grpc-java/` | `com.google.protobuf:protoc 3.24.3`; runtime protobuf is pulled through `grpc-protobuf` unless explicitly overridden | `io.grpc:* 1.82.1` | `protobuf-maven-plugin 0.6.1`; `protoc-gen-grpc-java 1.82.1` | `pom.xml` |
| Kotlin | `hello-grpc-kotlin/` | `protobufVersion 4.28.2`; `protobuf-java-util 4.28.2` | `grpc-java 1.82.1`; `grpc-kotlin 1.4.1` | Gradle protobuf plugin `0.10.0`; `protoc-gen-grpc-java 1.82.1`; `protoc-gen-grpc-kotlin 1.4.1` | `build.gradle.kts`, `stub/build.gradle.kts` |
| Node.js | `hello-grpc-nodejs/` | `google-protobuf ^3.21.2`; `@grpc/proto-loader ^0.7.15` | `@grpc/grpc-js ^1.14.0` | `grpc-tools ^1.12.4`; health `grpc-health-check ^2.0.1`; reflection `grpc-node-server-reflection ^1.0.2` | `package.json`; no project lockfile |
| PHP | `hello-grpc-php/` | `google/protobuf ^v4.30` | `grpc/grpc ^1.74.0` | Composer package is the project baseline; native PHP `grpc` extension may be absent locally | `composer.json`; no project lockfile |
| Python | `hello-grpc-python/` | `protobuf 6.33.5` | gRPC Python packages pinned to `1.81.1` | `grpcio-tools 1.81.1`; `grpcio-health-checking 1.81.1`; `grpcio-reflection 1.81.1` | `requirements.txt` |
| Rust | `hello-grpc-rust/` | Declared `prost 0.14.1`; resolved `prost 0.14.3` | `tonic 0.14.2` | `tonic-health` and `tonic-reflection` declared `0.14`, resolved `0.14.5`; `tonic-prost-build 0.14.2` | `Cargo.toml`, `Cargo.lock` |
| Swift | `hello-grpc-swift/` | `swift-protobuf 1.33.3` | `grpc-swift 2.2.3` | `grpc-swift-protobuf 1.3.1`; `grpc-swift-nio-transport 1.2.3` | `Package.swift`, `Package.resolved` |
| TypeScript | `hello-grpc-ts/` | `google-protobuf ^3.21.4`; `@grpc/proto-loader ^0.7.15` | `@grpc/grpc-js ^1.14.0` | `grpc-tools ^1.12.4`; `grpc_tools_node_protoc_ts ^5.3.3`; health/reflection same as Node.js | `package.json`; no project lockfile |

Version rules:

- Prefer exact pins for reproducible language projects. If a manifest uses a range such as `^`, keep this table explicit that it is a constraint, not a resolved lock.
- Keep protobuf runtime, protobuf compiler/plugin, and generated sources compatible. Do not bump a codegen tool without regenerating and testing the affected language output.
- For cross-language proto changes, regenerate only the affected language outputs and avoid hand-editing generated files.
- Run `scripts/check-versions.sh` when validating local gRPC/protobuf tooling.

## Build And Test Commands

Most language projects expose the same script pattern:

```sh
cd hello-grpc-python && ./scripts/build.sh
cd hello-grpc-go && ./scripts/server_start.sh
cd hello-grpc-ts && npm test
```

Use the native tool when it is clearer:

| Language | Command |
|---|---|
| C++ | `cd hello-grpc-cpp; bazel build //:hello_client //:hello_server` |
| C# | `cd hello-grpc-csharp; dotnet test` |
| Dart | `cd hello-grpc-dart; dart analyze; dart test` |
| Go | `cd hello-grpc-go; go test ./...` |
| Java | `cd hello-grpc-java; mvn test` |
| Kotlin | `cd hello-grpc-kotlin; gradle test` |
| Node.js | `cd hello-grpc-nodejs; npm test` |
| PHP | `cd hello-grpc-php; composer validate --strict; composer check-platform-reqs; vendor\bin\phpunit.bat` |
| Python | `cd hello-grpc-python; python -m unittest discover` |
| Rust | `cd hello-grpc-rust; cargo test` |
| Swift | `cd hello-grpc-swift; swift build` |
| TypeScript | `cd hello-grpc-ts; npm test` |

## Windows Local Toolchain

The primary local development environment for this workspace is Windows 11 (`windows/amd64`). Prefer PowerShell commands.

In this Codex runtime, prefix shell commands with `rtk`. For PowerShell cmdlets, use:

```sh
rtk proxy powershell -NoProfile -Command '<command>'
```

Current Windows toolchain snapshot:

| Language | Local toolchain | Verification command |
|---|---|---|
| C++ | Bazel `7.3.2`, CMake `4.3.3`, protoc `28.2` available locally; C++ build graph uses `protoc27.2.exe` for Bazel codegen | `cd hello-grpc-cpp; bazel build //:hello_client //:hello_server` |
| Rust | `rustc 1.95.0`, `cargo 1.95.0` | `cd hello-grpc-rust; cargo test` |
| Java | Temurin OpenJDK `25.0.3`, Maven `3.9.7` | `cd hello-grpc-java; mvn test` |
| Go | Go `1.26.4 windows/amd64` | `cd hello-grpc-go; go test ./...` |
| C# | .NET SDK `9.0.203` | `cd hello-grpc-csharp; dotnet test` |
| Python | Python `3.14.3` | `cd hello-grpc-python; python -m unittest discover` |
| Node.js | Node `22.23.0`, npm `11.15.0`, Yarn `1.22.22` | `cd hello-grpc-nodejs; npm test` |
| TypeScript | Node `22.23.0`, npm `11.15.0`, Yarn `1.22.22` | `cd hello-grpc-ts; npm test` |
| Dart | Dart SDK `3.9.2 stable` on `windows_x64` | `cd hello-grpc-dart; dart analyze; dart test` |
| Kotlin | Gradle `9.3.1`, Kotlin `2.2.21`, JVM `25.0.3` | `cd hello-grpc-kotlin; gradle test` |
| Swift | Swift `6.3.2` for `x86_64-unknown-windows-msvc` | `cd hello-grpc-swift; swift build` |
| PHP | PHP `8.5.7`, Composer `2.9.7` | `cd hello-grpc-php; composer validate --strict; composer check-platform-reqs; vendor\bin\phpunit.bat` |

Windows-specific notes:

- C++: `hello-grpc-cpp` uses Bazel with Bzlmod. `WORKSPACE` is intentionally renamed `WORKSPACE.bzlmod-off`. Native OpenTelemetry is disabled in the C++ build because the current BCR graph conflicts with the resolved gRPC/protobuf graph on Windows. `common/otel.cc` remains an env-gated no-op stub.
- C++: `rules_proto` is pinned to `6.0.2`; `protobuf` is pinned to `27.2`; `grpc` is pinned to `1.66.0`. `protos/BUILD.bazel` exposes `system_protoc` so Bazel can use `D:\zoo\bin\protoc27.2.exe`.
- Java/Kotlin: the local JDK is newer than the repository compatibility baseline. Treat Java 21 compatibility as the source target unless a language project explicitly updates it.
- Python: `where.exe python` may list the WindowsApps execution alias before `Python314`. Use the full Python path or fix PATH order when an exact interpreter matters.
- Node.js/TypeScript: prefer the package manager already used by the language directory. Do not mix npm and Yarn lockfile updates unless the project already does.
- Swift: `grpc-swift 2.2.3` currently has an upstream Windows support blocker in `RetryDelaySequence.swift`; distinguish that source-level limitation from SwiftPM scanner or target-info failures.
- PHP: confirm `where.exe php` before running PHP tests. Current PATH snapshots may contain stale PHP directories. Composer/PHPUnit may pass even when the native `grpc` extension is absent because this project uses the Composer `grpc/grpc` package.

## Coding Style

Follow each language ecosystem and the existing file style.

- Java uses Maven and `fmt-maven-plugin`.
- TypeScript uses strict `tsconfig.json`.
- Dart uses `analysis_options.yaml`.
- Swift follows Swift Package Manager layout.
- C++ uses Bazel.

Keep generated protobuf outputs in the owning language project and avoid hand-editing generated files such as `*_pb*`, `.pb.go`, `.pb.swift`, `.pbgrpc.dart`, or similar.

Preserve existing cross-language naming: `ProtoServer`, `ProtoClient`, `HelloService`, `Connection`, `ErrorMapper`, `LoggingConfig`, and their language equivalents.

## Testing

Add tests beside the implementation in the language's standard test directory: `src/test`, `tests`, `test`, or `Tests`.

Name tests after behavior, such as `HelloServiceTests`, `VersionTests`, `utils.test.ts`, or `proto_service_test.go`.

For cross-language behavior changes, update at least the affected implementation and run its local test command. For protobuf contract changes, run generation and tests for every touched language.

## Commits And Pull Requests

Recent commits use Conventional Commits with scopes, for example:

```text
feat(swift): complete OTel per-RPC span wiring
fix(go): map grpc errors consistently
```

Pull requests should describe affected language(s), commands run, generated proto updates, and any Docker or Kubernetes impact. Link issues when applicable and include logs or screenshots only for user-visible behavior.

## Security And Runtime Configuration

Do not commit private keys outside existing demo TLS material.

Tracing is opt-in via `GRPC_HELLO_OTEL=Y`; keep default runtime behavior unchanged unless the change explicitly targets observability.

TLS configuration is consistent across languages:

- `GRPC_HELLO_SECURE=Y` enables TLS.
- `CERT_BASE_PATH` overrides the certificate directory.
- Certificate directories contain files such as `full_chain.pem`, `private.key`, and `myssl_root.cer`.
- Missing or invalid certificates fail fast.
- `GRPC_HELLO_INSECURE_FALLBACK=Y` explicitly permits falling back to an insecure connection when TLS setup fails; never enable it by default.
