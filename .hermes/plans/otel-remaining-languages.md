# OpenTelemetry — 10-language milestone (DONE)

## Status (2026-06-30)

- [x] **#486 Go**        : merged (commit d5aa0bd) — `feat/go-otel-interceptor`
- [x] **#488 Python**    : merged (commit 2aef3f5) — `feat/python-otel`
- [x] **#489 Node.js+TS**: merged (commit 89080ce) — `feat/nodejs-ts-otel`
- [x] **#490 Rust**      : merged (commit ecffcb5) — `feat/rust-otel`
- [x] **#491 C#**        : merged (commit 7401663) — `feat/csharp-otel`
- [x] **#492 C++**       : merged (commit 65bd290) — `feat/cpp-otel`
- [x] **#493 PHP**       : merged (commit 5e624c7) — `feat/php-otel` (SDK + exporter; per-call span deferred)
- [x] **#494 Dart**      : merged (commit 07e7005) — `feat/dart-otel` (SDK + tracer; per-RPC interceptor deferred)
- [x] **#495 deps**      : merged (commit 74451ff) — `chore(deps): bump grpc-java 1.78.0 -> 1.82.1`
- [x] **#496 Java v2**   : merged (commit 6ab6341) — `feat/java-otel-v2` (uses opentelemetry-grpc-1.6 contrib library)
- [x] **#497 Kotlin**    : merged (commit e15da66) — `feat/kotlin-otel`
- [x] **#498 Swift**     : merged (commit acf68f5) — `feat/swift-otel` (SDK scaffolding; per-RPC interceptor deferred)

## Java dep bump note

PR #495 bumps grpc-java to **1.82.1** (the latest stable on Maven Central at
the time). The OTel wiring in #496/#497 uses
`io.opentelemetry.instrumentation:opentelemetry-grpc-1.6`, which supports
grpc-java 1.6+, so 1.85.x is not required for this milestone.

## Known partial implementations

Three languages merged with only SDK-level OTel wiring because their
gRPC runtimes lack a vendored OTel interceptor package:

- **PHP** (`hello-grpc-php`): ext-grpc does not expose interceptor hooks.
  Next step: wrap each service handler in `hello_server.php` with a manual
  `Otel::tracer()->spanBuilder()->startSpan()/end()` pair.
- **Dart** (`hello-grpc-dart`): `grpc-dart` 4.x has no first-class OTel
  integration. Next step: write a custom `ClientInterceptor` and
  `ServerInterceptor` that use `Otel.tracer`.
- **Swift** (`hello-grpc-swift`): no `opentelemetry-swift` gRPC
  instrumentation package exists. Next step: replace the placeholder
  tracer in `Sources/Common/Otel.swift` with a real
  `opentelemetry-swift` `TracerProvider`, then add custom
  `ServerInterceptor` / `ClientInterceptor` wrappers.

## What not to touch yet

1. **Java OTel revisit**: closed by #496. Do not re-bump grpc-java to
   1.85.x unless there is an independent reason; 1.82.1 works.
2. **Kotlin OTel**: closed by #497; relies on grpc-kotlin 1.4.1 and the
   existing grpc-java 1.68.0 pin.

## Remaining follow-up PRs (prioritised)

1. Build CI verification report: for each OTel PR, capture the latest
   CI workflow run status and note which failures are pre-existing vs
   OTel-related.
2. PHP/Dart/Swift per-RPC span follow-up PRs.
3. Optional repo-wide grpc-java 1.85.x bump if/when Maven Central
   publishes a newer stable.
