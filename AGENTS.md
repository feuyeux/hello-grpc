# Hello gRPC Contributor Guide

## Scope

`hello-grpc` is a cross-language gRPC interoperability and learning repository. It provides comparable clients and servers in C++, C#, Dart, Go, Java, Kotlin, Node.js, PHP, Python, Rust, Swift, and TypeScript, plus Docker, TLS, proxy, Kubernetes, gateway, mesh, tracing, and application examples.

Each language implementation is isolated in a `hello-grpc-<language>/` directory. There is no repository-wide language build; use the toolchain and scripts owned by the implementation you change.

## Shared Contracts

[`proto/landing.proto`](proto/landing.proto) is the canonical contract for language implementations. It defines `LandingService` and four RPC styles:

1. `Talk` — unary request/response.
2. `TalkOneAnswerMore` — server streaming.
3. `TalkMoreAnswerOne` — client streaming.
4. `TalkBidirectional` — bidirectional streaming.

`TalkRequest` contains `data` and `meta`; `TalkResponse` contains `status` and repeated `TalkResult` entries. Preserve streaming semantics, field numbers, package options, and error behavior across language implementations.

[`proto-gateway/landing2.proto`](proto-gateway/landing2.proto) is a separate contract for gRPC-JSON gateway experiments. It includes HTTP annotations and must not replace or be used as a variant of `proto/landing.proto` in language implementations.

### Changing a Proto Contract

1. Change `proto/landing.proto` first.
2. Regenerate code only in affected language directories using their established generators or build scripts.
3. Never hand-edit generated protobuf/gRPC output (`*_pb*`, `.pb.go`, `.pb.swift`, `.pbgrpc.dart`, and equivalents).
4. Update each affected implementation, test its corresponding RPC shape, and document any compatibility impact.

## Layout

- `proto/` — shared language contract.
- `proto-gateway/` — gateway-only annotated contract.
- `hello-grpc-*/` — self-contained implementations, dependencies, generated outputs, source, and tests.
- `docker/` — multi-language container build, run, TLS, and smoke-test tooling.
- `scripts/` — shared version checks and TLS, proxy, benchmark, Kubernetes, mesh, and tracing scenarios.
- `integration-tests/` — cross-implementation checks.
- `doc/` — feature-parity and supporting documentation.
- `hello-grpc-app/` — gateway and desktop/mobile application experiments.

## Development and Validation

Inspect and use the selected implementation's native manifest and scripts. Representative commands are:

```sh
cd hello-grpc-go && go test ./...
cd hello-grpc-java && mvn test
cd hello-grpc-python && python -m unittest discover -s tests
cd hello-grpc-nodejs && npm test
cd hello-grpc-rust && cargo test
```

Most implementations also provide `scripts/build.sh`, `scripts/server_start.sh`, `scripts/client_start.sh`, and `scripts/stop_server.sh`. Build scripts can generate code or manage local dependencies, so review their behavior before running them. Use `scripts/check-versions.sh` to inspect local protobuf and gRPC tooling when a toolchain mismatch is suspected.

For a behavior change, test the language implementation changed. For a contract change, test every regenerated or modified implementation and, where relevant, an interoperability path. Docker, TLS, proxy, discovery, Kubernetes, mesh, and observability validation are scenario-specific; run only the scenario affected by the change.

## Code Standards

- Follow each language's existing style, formatter, package manager, and lockfile conventions.
- Preserve cross-language naming where it already exists: `ProtoServer`, `ProtoClient`, `HelloService`, `Connection`, `ErrorMapper`, and logging/interceptor equivalents.
- Keep business behavior equivalent across languages: validate input, retain response shape, propagate relevant headers/tracing data, and map gRPC errors consistently.
- Add tests in the implementation's standard test location (`src/test`, `tests`, `test`, or `Tests`) and name them after observable behavior.
- Do not commit generated build directories, local virtual environments, credentials, private keys, or local TLS material beyond the repository's existing demo certificates.

## Runtime Configuration and Security

TLS is controlled consistently with `GRPC_HELLO_SECURE=Y`; `CERT_BASE_PATH` can override the certificate directory. Missing or invalid certificate material must fail fast. `GRPC_HELLO_INSECURE_FALLBACK=Y` is an explicit opt-in and must never become the default. OpenTelemetry behavior is opt-in through `GRPC_HELLO_OTEL=Y`; preserve default runtime behavior unless observability is the task.
