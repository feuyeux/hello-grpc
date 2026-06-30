# Hello-gRPC Capability Parity Audit — SOP

## Goal
Build a verified parity matrix across 14 language implementations of hello-grpc.
For every (language × capability) cell: ✅ implemented / ⚪ absent / ❓ uncertain,
backed by file:line evidence, never README-claims alone.

## Capabilities to Audit (22)
Group A — gRPC contract basics
  A1  Unary RPC
  A2  Server-streaming RPC
  A3  Client-streaming RPC
  A4  Bidi-streaming RPC
  A5  Metadata propagation (custom headers)
  A6  Trailers / status code handling
  A7  Deadlines & cancellation (with_timeout / context-with-deadline)

Group B — production-grade features
  B1  TLS server (server-side cert)
  B2  mTLS client (client-side cert)
  B3  Interceptors — client side
  B4  Interceptors — server side
  B5  Health check service (grpc.health.v1)
  B6  Reflection service (gRPC Server Reflection)
  B7  Compression (gzip / snappy)

Group C — advanced / ecosystem
  C1  Service discovery (etcd / nacos / consul / k8s)
  C2  Client-side load balancing policy (round_robin / grpclb / xds)
  C3  xDS support
  C4  Retry policy (service config / with_max_retry)
  C5  Name resolver (custom DNS / etcd)
  C6  OpenTelemetry / tracing hooks

## Decision Rules
- ✅  Implemented: code path exists AND referenced from a runnable target
      (server / client). Cite file:line where the call is wired up.
- ⚪  Absent:    no code reference; capability not in proto, not in build,
      no env var documenting it. Note why if obvious (e.g. "not in this
      language's grpc library").
- ❓  Uncertain: code mentions the symbol but not actually invoked, or
      stub / comment-only. List the file:line so a human can resolve.

## Anti-Patterns
- Do NOT count README as proof. README = hypothesis, code = proof.
- Do NOT mark ✅ when the only evidence is a TODO/FIXME comment.
- Do NOT assume absence = bug; some languages genuinely cannot do some
  things (e.g. PHP mTLS client auth quirks). Annotate.
- Do NOT mark ✅ for libraries installed but not used. e.g.
  `requirements.txt` listing `opentelemetry-api` does not count — must
  see `tracer.start_as_current_span(...)` actually wired in a call path.

## Output Schema (per sub-agent batch)
```
| Lang    | A1 | A2 | A3 | A4 | A5 | A6 | A7 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | C1 | C2 | C3 | C4 | C5 | C6 |
| C++     | .. | .. |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |    |
...
```
Evidence per non-empty cell: `path:line — one-line justification`.
Summary at the end: top 5 most-missing capabilities by language count.

## Sub-Agent Allocation (3 batches, parallel)
Batch 1: Go / Python / Java / C++ / Rust
Batch 2: Node.js / TypeScript / C# / Kotlin / Swift
Batch 3: Dart / PHP / Rust (recheck if needed) / cross-cutting checks
         (proto contents, scripts/tls, scripts/proxy, doc coverage)

Working dir: D:\coding\hello-grpc
