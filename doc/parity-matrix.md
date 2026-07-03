# hello-grpc Feature Parity Matrix

**12 x 20 matrix** - 12 languages x 20 capability columns (A1-A7, B1-B7, C1-C6).

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

| Lang       | A1 | A2 | A3 | A4 | A5 | A6 | A7 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | C1 | C2 | C3 | C4 | C5 | C6 |
|------------|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|
| Go         | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Python     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Java       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C++        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Rust       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Node.js    | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| TypeScript | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| C#         | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Kotlin     | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Swift      | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Dart       | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PHP        | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Summary by Language

| Lang       | ✅ | ⚪ | Remaining gaps |
|------------|---|---|----------------|
| Go         | 20 | 0 | None |
| Python     | 20 | 0 | None |
| Java       | 20 | 0 | None |
| C++        | 20 | 0 | None |
| Rust       | 20 | 0 | None |
| Node.js    | 20 | 0 | None |
| TypeScript | 20 | 0 | None |
| C#         | 20 | 0 | None |
| Kotlin     | 20 | 0 | None |
| Swift      | 20 | 0 | None |
| Dart       | 20 | 0 | None |
| PHP        | 20 | 0 | None |

## Notes on Implementation Parity

- **Core RPC parity**: `proto/landing.proto` defines the four RPC shapes, and each language server implements all four methods on its registered `LandingService` path. The matching clients exercise all four call shapes.
- **TLS and metadata**: TLS is wired through each language's connection/server startup path using `GRPC_HELLO_SECURE` or equivalent command-line handling. Metadata/header propagation is counted where headers are read from incoming calls and forwarded to backend/proxy calls or injected by client/server interceptors.
- **Error mapping**: Error status mapping is present through language-local `ErrorMapper` helpers or explicit `Status`/exception translation on RPC failures.
- **Observability**: B2 is counted only where an `rpc_calls_total`-style counter is created and incremented from the RPC path with the repository's OTel gate. Some implementations use SDK metric exporters, while Rust/Swift/PHP keep lightweight in-process/logged counters under the same `GRPC_HELLO_OTEL=Y` gate.
- **C++ observability**: `hello-grpc-cpp/common/otel.cc` is currently native `opentelemetry-cpp` wiring behind `GRPC_HELLO_OTEL=Y`; `server/proto_server.cpp` calls `RecordRpcCall` and `EmitRpcSpan` from each RPC method path.
- **Swift source parity**: Swift registers `HealthService` and `ReflectionService` in `HelloServer.swift`, and enables `HelloServerInterceptor`/`HelloClientInterceptor` when `GRPC_HELLO_OTEL=Y`. The source implementation is counted even though Windows build verification is still blocked by upstream `grpc-swift` Windows support.
- **Dart reflection**: Dart has a handwritten reflection service that answers service listing, file-by-filename, and file-containing-symbol requests for `landing.proto`.
- **PHP reflection and middleware**: PHP registers handwritten health and reflection service implementations alongside `LandingService`, and uses a service-level middleware chain because the PHP gRPC extension does not expose a standard server interceptor hook.

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
| Go | `go test ./...` | Not rerun in this audit; source path audited. |
| Python | `python -m unittest discover` | Not rerun in this audit; source path audited. |
| Java | `mvn test` | Not rerun in this audit; source path audited. |
| C++ | `bazel build //:hello_client //:hello_server` | Not rerun in this audit; source path audited. Known Windows protobuf/toolchain risk remains separate from source parity. |
| Rust | `cargo test` | Not rerun in this audit; source path audited. |
| Node.js | `npm test` | Not rerun in this audit; source path audited. |
| TypeScript | `npm test` | Not rerun in this audit; source path audited. |
| C# | `dotnet test` | Not rerun in this audit; source path audited. |
| Kotlin | `gradle test` | Not rerun in this audit; source path audited. |
| Swift | `swift build` | Not rerun in this audit; source path audited. Upstream `grpc-swift` Windows support remains the known build blocker. |
| Dart | `dart analyze`; `dart test` | Not rerun in this audit; source path audited. |
| PHP | `composer validate --strict`; `vendor\bin\phpunit.bat` | Not rerun in this audit; source path audited. |

---

## C3 Helm Chart

Helm chart at `scripts/k8s/helm/hello-grpc/` enables/disables each language server through `values.yaml`. A duplicate chart also exists at `scripts/k8s/helm/`.

---

*Last updated: 2026-07-02. Source: source audit against current workspace (generated/vendor/node_modules/venv/build outputs excluded).*
