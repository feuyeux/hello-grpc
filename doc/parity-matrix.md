# hello-grpc Feature Parity Matrix

**12 x 23 matrix** - 12 languages x 23 capability columns (A1-A10, B1-B7, C1-C6).

Symbols: ✅ = implemented and registered on the current source path · ⚪ = absent, stub-only, or not registered

Build/runtime verification blockers are tracked separately in the verification notes. They do not change a feature cell when the source implementation is present and wired.

## Audit Scope

This document reflects a source audit of the current workspace. It counts checked-in source and deployment assets, including currently uncommitted files in this working tree. It does not claim that every language was rebuilt in this audit pass.

## Audit Rules

- Build verification blockers (for example the C++ Windows protoc crash and missing upstream grpc-swift Windows support, both tracked in AGENTS.md "Windows Local Toolchain") do not downgrade feature cells. A ✅ means the source implementation is present and wired, not that the language builds and passes CI on every platform.
- Generated protobuf bindings, `vendor/`, `node_modules/`, virtualenvs, and build outputs are not counted as feature implementations.
- A helper alone is not counted. The feature must be wired into the server/client path used by the language implementation.
- Metrics are counted for B2 only when an `rpc_calls_total`-style RPC counter is created and incremented from the running RPC path behind the `GRPC_HELLO_OTEL=Y` gate.
- Reflection is counted for C4 only when the service can answer reflection requests, not when a placeholder service returns `UNIMPLEMENTED`.
- Deployment columns C1-C3 and C6 count repository assets: Dockerfiles, Kubernetes manifests, Helm values/templates, and GitHub Actions workflows.

## Column Legend

### Group A - Core gRPC Features

| ID | Feature |
|----|---------|
| A1 | Unary RPC |
| A2 | Server-streaming RPC |
| A3 | Client-streaming RPC |
| A4 | Bidirectional-streaming RPC |
| A5 | TLS / secure channel |
| A6 | Metadata (headers) propagation |
| A7 | Error status mapping |
| A8 | Client retry policy (A6 client retries, `UNAVAILABLE`, channel-level service config or equivalent application-level retry) |
| A9 | Client-side HTTP/2 keepalive |
| A10 | gzip message compression (channel/call level) |

### Group B - Observability

| ID | Feature |
|----|---------|
| B1 | Structured logging |
| B2 | Metrics (`rpc_calls_total` counter, OTel-gated) |
| B3 | Distributed tracing - span creation |
| B4 | Distributed tracing - context propagation |
| B5 | Distributed tracing - per-RPC attributes (`rpc.system`, `rpc.method`) |
| B6 | OTel SDK wired (`GRPC_HELLO_OTEL=Y`) |
| B7 | Health-check endpoint |

### Group C - Deployment & Operations

| ID | Feature |
|----|---------|
| C1 | Docker image / Dockerfile |
| C2 | Kubernetes manifest |
| C3 | Helm chart |
| C4 | gRPC server reflection |
| C5 | Interceptor / middleware chain |
| C6 | CI pipeline (GitHub Actions) |

---

## Parity Matrix

| Lang       | A1 | A2 | A3 | A4 | A5 | A6 | A7 | A8 | A9 | A10 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | C1 | C2 | C3 | C4 | C5 | C6 |
|------------|----|----|----|----|----|----|----|----|----|-----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| Go         | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Python     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Java       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C++        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Rust       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Node.js    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| TypeScript | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C#         | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Kotlin     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Swift      | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Dart       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PHP        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**A8 implementation note**: Go, Python, Java, C++, Node.js, TypeScript, C#, Kotlin, and PHP implement A8 as a channel-level `grpc.service_config` `retryPolicy` (maxAttempts=4, initialBackoff=0.1s, maxBackoff=1s, multiplier=2.0, retryable=`UNAVAILABLE`) applied at connection setup. Rust (`hello-grpc-rust/src/common/conn.rs`), Swift (`hello-grpc-swift/Sources/Common/Retry.swift`), and Dart (`hello-grpc-dart/lib/conn/retry.dart`) implement the same policy as an application-level retry wrapper around the unary `Talk` call, because tonic, grpc-swift, and the Dart `grpc` package have no built-in service-config/retryPolicy support.

**A10 implementation note**: gzip compression is enabled at the client channel level in Go (`grpc.UseCompressor(gzip.Name)`), Python (`compression=grpc.Compression.Gzip` channel kwarg), Java (`.withCompression("gzip")` on both stubs), Kotlin (`.withCompression("gzip")` on the coroutine stub), C++ (`grpc.default_compression_algorithm` / `SetCompressionAlgorithm(GRPC_COMPRESS_GZIP)` channel arg), C# (`GrpcChannelOptions.CompressionProviders` with `GzipCompressionProvider`), Node.js/TypeScript (`grpc.default_compression_algorithm: 2` channel arg on `@grpc/grpc-js`), PHP (`grpc.default_compression_algorithm => 2` channel arg), and Rust (`tonic`'s `send_compressed`/`accept_compressed(CompressionEncoding::Gzip)` with the `gzip` cargo feature enabled). **Swift and Dart are ⚪**: grpc-swift 2.x's `HTTP2ClientTransport.Posix.Config` and the Dart `grpc` package's `ChannelOptions` (both pinned per AGENTS.md) currently expose no message-compression/codec configuration hook, so there is no API surface to wire this into yet.

---

## Summary by Language

| Lang       | ✅ | ⚪ | Remaining gaps |
|------------|---|---|----------------|
| Go         | 23 | 0 | None |
| Python     | 23 | 0 | None |
| Java       | 23 | 0 | None |
| C++        | 23 | 0 | None |
| Rust       | 23 | 0 | None |
| Node.js    | 23 | 0 | None |
| TypeScript | 23 | 0 | None |
| C#         | 23 | 0 | None |
| Kotlin     | 23 | 0 | None |
| Swift      | 22 | 1 | A10: grpc-swift 2.x has no message-compression config hook |
| Dart       | 22 | 1 | A10: Dart `grpc` package has no message-compression config hook |
| PHP        | 23 | 0 | None |

## Notes on Implementation Parity

- **Core RPC parity**: `proto/landing.proto` defines the four RPC shapes, and each language server implements all four methods on its registered `LandingService` path. The matching clients exercise all four call shapes.
- **TLS and metadata**: TLS is wired through each language's connection/server startup path using `GRPC_HELLO_SECURE` or equivalent command-line handling. Metadata/header propagation is counted where headers are read from incoming calls and forwarded to backend/proxy calls or injected by client/server interceptors.
- **Error mapping**: Error status mapping is present through language-local `ErrorMapper` helpers or explicit `Status`/exception translation on RPC failures.
- **Observability**: B2 is counted only where an `rpc_calls_total`-style counter is created and incremented from the RPC path with the repository's OTel gate. Some implementations use SDK metric exporters, while Rust/Swift/PHP keep lightweight in-process/logged counters under the same `GRPC_HELLO_OTEL=Y` gate.
- **C++ observability**: `hello-grpc-cpp/common/otel.cc` is currently native `opentelemetry-cpp` wiring behind `GRPC_HELLO_OTEL=Y`; `server/proto_server.cpp` calls `RecordRpcCall` and `EmitRpcSpan` from each RPC method path.
- **Swift source parity**: Swift registers `HealthService` and `ReflectionService` in `HelloServer.swift`, and enables `HelloServerInterceptor`/`HelloClientInterceptor` when `GRPC_HELLO_OTEL=Y`. The source implementation is counted even though Windows build verification is still blocked by upstream `grpc-swift` Windows support.
- **Dart reflection**: Dart has a handwritten reflection service that answers service listing, file-by-filename, and file-containing-symbol requests for `landing.proto`.
- **PHP reflection and middleware**: PHP registers handwritten health and reflection service implementations alongside `LandingService`, and uses a service-level middleware chain because the PHP gRPC extension does not expose a standard server interceptor hook.
- **etcd service discovery**: When `GRPC_HELLO_DISCOVERY=etcd` is set, the server registers its `host:port` with etcd (lease-based keepalive) and the client resolves the target address from etcd before connecting. Implemented in Go, Java, Python, Rust, C#, Node.js, TypeScript, PHP, and Kotlin (9 languages). Go and Java use their ecosystem's native etcd client (`go.etcd.io/etcd/client/v3` and `io.etcd.jetcd`); the other 7 use the etcd v3 HTTP gRPC-gateway API — no native etcd client library required. Swift and Dart are blocked: neither ecosystem has an etcd client library or an HTTP client suitable for the v3 API.

## Source Audit Evidence

| Lang | Current source evidence |
|------|-------------------------|
| Go | `server/proto_server.go` registers LandingService, health, reflection, unary interceptors, stats handler, and metrics endpoint; `server/service/proto_service.go` implements all four RPCs and records RPC calls. |
| Python | `server/protoServer.py` registers LandingService, health, reflection, logging/OTel interceptors, TLS, metrics counter, and all four RPCs. |
| Java | `server/ProtoServer.java` registers intercepted LandingService, health, and reflection; `server/LandingServiceImpl.java` implements all four RPCs and increments `rpc_calls_total`. |
| C++ | `server/proto_server.cpp` implements all four RPCs, TLS, metadata propagation, health, reflection, interceptor, and OTel calls; `common/BUILD.bazel` links `common/otel.cc`. |
| Rust | `src/landing/server.rs` registers LandingService with interceptor, health, reflection, TLS, lightweight metrics, and all four tonic RPC methods. |
| Node.js | `src/server/index.js` wraps the service with logging middleware, registers health and reflection, handles TLS, propagates metadata, records `rpc_calls_total`, and implements all four RPCs. |
| TypeScript | `src/hello_server.ts` mirrors the Node.js server with typed service handlers, health/reflection registration, middleware, OTel-gated counter, TLS, and metadata propagation. |
| C# | `HelloServer/ProtoServer.cs` registers gRPC services, health checks, reflection, interceptor, TLS, and OTel providers; `LandingServiceImpl.cs` implements and counts all four RPCs. |
| Kotlin | `server/ProtoServer.kt` registers intercepted LandingService, health, reflection, TLS, and OTel; `server/LandingService.kt` implements and counts all four RPCs. |
| Swift | `Sources/Server/HelloServer.swift` registers LandingService, health, reflection, TLS, and OTel interceptors; `HelloService.swift` implements all four RPCs. |
| Dart | `lib/server.dart` registers LandingService, health, reflection, TLS, server interceptor, OTel-gated counter, metadata forwarding, and all four RPCs. |
| PHP | `hello_server.php` registers LandingService, health, reflection, and TLS; `LandingService.php` implements all four RPCs and wraps handlers in middleware/OTel. |

## Verification Notes

| Language | Command | Result |
|----------|---------|--------|
| Go | `go test ./...` | PASS (2026-07-04). common + server/service tests passed. |
| Python | `python -m unittest discover -s tests` | PARTIAL (2026-07-04). 2/3 test modules pass; `test_landing_service` fails on `ImportError: cannot import name 'build_result' from 'server.protoServer'`. |
| Java | `mvn test` | PARTIAL (2026-07-04). 1/2 tests pass; `LandingServiceImplTest` fails with `AbstractMethodError` in `InMemoryServerBuilder` — JDK 25 / grpc-java compatibility issue. |
| C++ | `bazel build //:hello_client //:hello_server` | FAIL (2026-07-04). `protos/BUILD.bazel` references `D:\zoo\bin\protoc27.2.exe` which does not exist on this machine. Known Windows protobuf/toolchain risk. |
| Rust | `cargo test` | PASS (2026-07-04). 3 tests + 1 doctest passed; 2 deprecation warnings in `rnd_test.rs`. |
| Node.js | `npm test` | PASS (2026-07-04). 2 tests passed. |
| TypeScript | `npm test` | PASS (2026-07-04). 15 tests passed. |
| C# | `dotnet test` | PASS (2026-07-04). 3 tests passed; 1 NuGet vulnerability warning for log4net 3.0.4. |
| Kotlin | `gradle test` | FAIL (2026-07-04). `:stub:compileKotlin` fails with `IllegalArgumentException: 25.0.3` — Kotlin compiler does not support JDK 25 target. |
| Swift | `swift build` | FAIL (2026-07-04). Timed out after 5min; `swift-nio-extras` fails with `no such module 'Glibc'` on Windows. Known upstream `grpc-swift` Windows blocker. |
| Dart | `dart analyze`; `dart test` | PASS (2026-07-04). 4 tests passed; 18 info-level analyzer issues (no errors). |
| PHP | `composer validate --strict`; `vendor\bin\phpunit.bat` | PASS (2026-07-04). composer valid; 2 tests passed. gRPC extension not loaded (using Composer package). |

---

## C3 Helm Chart

Helm chart at `scripts/k8s/helm/` enables/disables each language server through `values.yaml`.

---

*Last updated: 2026-07-04. Source: source audit + build verification + etcd service discovery audit against current workspace (generated/vendor/node_modules/venv/build outputs excluded).*
