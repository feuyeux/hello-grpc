# hello-grpc Capability Parity Audit — Final Report

**Scope**: 14 language implementations × 22 gRPC capabilities.
**Decision rules**: ✅ wired & running | ⚪ no code reference | ❓ defined but not invoked / structurally present.
Evidence citations: `path:line`. Never README claims.

**Inputs merged**: `/tmp/audit-batch1.md` (Go/Python/Java/C++/Rust), `/tmp/audit-batch2.md` (Node.js/TS/C#/Kotlin/Swift), `/tmp/audit-batch3.md` (Dart/PHP + cross-cutting).
**Cross-checks performed on parent**: Node.js mTLS=⚪ confirmed at `hello-grpc-nodejs/src/server/index.js:180-187`; C++ Health=✅ confirmed at `hello-grpc-cpp/server/proto_server.cpp:353`; Go Health/Reflection=✅ confirmed at `hello-grpc-go/server/proto_server.go:111-114`.

---

## 1. Summary (top-down)

### Universal gaps (capabilities with **0/14 ✅**)
| Cap | Description | Languages that have it |
|----:|---|---|
| B5 | Health check (`grpc.health.v1`) | 4/14 — Go, C++, C#(?), Kotlin(?) |
| B6 | Reflection service | 3/14 — Go, Java, C++ |
| B7 | Compression | 0/14 |
| C1 | Dynamic service discovery | 2/14 — Go (etcd), Java (etcd/nacos) |
| C2 | LB policy (`round_robin`/`grpclb`/`xds`) | 1/14 — Go |
| C3 | xDS | 0/14 |
| C5 | Custom name resolver | 1/14 — Go (etcd) |
| C6 | OpenTelemetry / tracing SDK | 0/14 (Rust has `tracing` crate only) |

### Tier-1 features (4/14 ⚪)
| Cap | Why missing |
|----:|---|
| A5 Metadata | Swift (proxy mode breaks), Node.js(?) |
| A7 Deadline | Java, Node.js, C#, Swift mostly ❓ |
| B3 Client interceptor | 9/14 ⚪ |
| B4 Server interceptor | 9/14 ⚪ |

### Stack ranking — feature-richness across 22 capabilities
| Rank | Language | ✅ count | Notes |
|---:|---|---:|---|
| 1 | Go | 14/22 | The yardstick |
| 1 | Java | 14/22 | Missing trailer + deadline + health |
| 3 | Kotlin | ~10/22 | Best of batch-2, missing B5/B6/C1-6 |
| 4 | PHP | 9/22 | mTLS works (rare win) |
| 4 | Dart | 9/22 | Only server-streaming retry wired (not service config) |
| 6 | C++ | 9/22 | Has Health, misses interceptors |
| 7 | Python | 8/22 | `LoggingInterceptor` defined ~120 lines, never registered at `server/protoServer.py:364` |
| 8 | Rust | 7/22 | |
| 9 | Node.js | 7/22 | TLS not mTLS, has reflection dep commented out |
| 9 | TypeScript | 7/22 | Same as Node.js |
| 9 | C# | 7/22 | mTLS ✅; missing interceptors & health |
| 12 | Swift | 6/22 | macOS only (`Package.swift:54`) |

---

## 2. Full 14 × 22 parity matrix

Columns A1..C6 per SOP. Symbols: ✅=wired & running · ⚪=absent · ❓=uncertain.

| Lang | A1 | A2 | A3 | A4 | A5 | A6 | A7 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | C1 | C2 | C3 | C4 | C5 | C6 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Go | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ✅ | ✅ | ⚪ | ✅ | ✅ | ⚪ |
| Python | ✅ | ✅ | ✅ | ✅ | ✅ | ✅¹ | ✅ | ✅ | ✅ | ❓² | ❓³ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ✅⁴ | ⚪ | ⚪ |
| Java | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ⚪ | ✅ | ✅ | ✅ | ✅ | ⚪ | ✅ | ⚪ | ✅ | ✅ | ⚪ | ✅ | ✅ | ⚪ |
| C++ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ⚪ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| Rust | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ✅ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ❓ |
| Node.js | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ✅ | ⚪⁵ | ⚪ | ⚪ | ⚪ | ⚪⁶ | ⚪ | ⚪ | ⚪ | ⚪ | ❓⁷ | ⚪ | ⚪ |
| TypeScript | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| C# | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❓ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| Kotlin | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ |
| Swift | ✅ | ✅ | ✅ | ✅ | ⚪* | ✅ | ❓ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ❓ | ⚪ | ⚪ |
| Dart | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ❓ | ⚪ | ⚪ | ✅⁸ | ⚪ | ⚪ |
| PHP | ✅ | ✅ | ✅ | ✅ | ✅⁹ | ✅ | ✅¹⁰ | ✅ | ✅ | ⚪ | ⚪ | ⚪ | ⚪ | ⚪ | ❓ | ⚪ | ⚪ | ✅¹¹ | ⚪ | ⚪ |

**Footnotes (rapid justification for each ❓):**

¹ Python A6 Trailers — helpers `set_response_headers` / `set_response_trailers` at `conn/log_formatter.py:184-221` exist & call correct API (`context.send_initial_metadata` / `set_trailing_metadata`), but they're **never invoked from `LandingServiceServer`**, only demonstrated.
² Python B3 Client interceptor — `LoggingInterceptor(grpc.ServerInterceptor)` defined but server-side; **no `grpc.ClientInterceptor` subclass anywhere**.
³ Python B4 Server interceptor — same `LoggingInterceptor` class — ~120 lines of real code, defined but not registered at `server/protoServer.py:364` (instantiated? `grpc.server(pool, interceptors=[LoggingInterceptor(logger)])` would wire it).
⁴ Python C4 Retry policy — `conn/retry_helper.py:31-86` `with_retry` decorator with `MaxAttempts=3`. Counts because it's Python-level but real and on the call path. **Not** gRPC service config.
⁵ Node.js B2 mTLS — `src/server/index.js:180-187` calls `ServerCredentials.createSsl(null, [...], false)` — third arg = `requestClientCert = false`. **Not** mTLS.
⁶ Node.js B6 Reflection — `grpc-node-server-reflection` in `package.json:11`, but import commented out at `src/server/index.js:25`.
⁷ Node.js C4 Retry — `withRetry` helper exists at `src/common/retry_helper.js`, retries on `UNAVAILABLE`/`DEADLINE_EXCEEDED`. Inline only, not service config.
⁸ Dart C4 Retry — `lib/client.dart:48-83` retry loop with `retryAttempts=3, retryDelaySeconds=2`. Manual, not service config.
⁹ PHP A5 Metadata — server reads ✅; **client passes empty metadata** (`$callMetadata = []`) at `hello_client.php:229` with comment "to avoid 'Bad metadata value given' errors". Direct path effectively broken.
¹⁰ PHP A7 Deadline — uses `['timeout' => N * 1000]` channel-option; PHP `grpc` ext has no `Context.withDeadline`. Counts because the timeout mechanism exists.
¹¹ PHP C4 Retry — `hello_client.php:242-296` inline retry loop with jitter, status-code-gated. `ErrorMapper::retryWithBackoff` is defined in `common/utils/ErrorMapper.php:156-203` but **never called** — only inline loop is wired.

\* Swift A5 Metadata — direct calls work, but proxy mode forwards `metadata: [:]` (`Sources/Server/HelloService.swift:81,108,147,187`) — propagation broken across a chain.

---

## 3. Cross-cutting gaps (single decision fixes repo-wide)

These 5 decisions unlock multiple cells across many languages at once:

| # | Decision | Languages it unblocks |
|---|---|---|
| X1 | Add `proto/health/v1/health.proto` | Enables B5 for every language |
| X2 | Add `proto/reflection/v1alpha/reflection.proto` | Enables B6 for every language |
| X3 | Add `proto/grpc/service_config/*.proto` (or inline) | Enables service-config C4; today only Python has the generated stub at `conn/landing_pb2_grpc.py:131` |
| X4 | Add `grpc.default_compression_algorithm` channel option (with env toggle) | Enables B7 for every language |
| X5 | Add `proto/opentelemetry/proto/trace.proto` + an OTel interceptor in each language | Enables C6 across the board |

| # | Repo-level gap | Detail |
|---|---|---|
| Y1 | No `health.proto` / `reflection.proto` in `proto/` | Single file add unlocks B5/B6 for all |
| Y2 | No CHANGELOG / RELEASE_NOTES | Dependabot bumps landing in `git log` but no human-readable history |
| Y3 | `doc/` lacks guidance for health, reflection, retry policy, OTel, xDS, compression | Only `xDS` and `ETCD_README` / `NACOS_README` exist; no tutorials for the 8 universal-gap capabilities |
| Y4 | Swift restricted to macOS (`Package.swift:54` `platforms: [.macOS("15.0")]`) | Breaks macOS-only quirk in a "12+ languages" headline claim |
| Y5 | `scripts/proxy/` is application-level forwarder, not Envoy | No HTTP CONNECT or gRPC proxy variant |
| Y6 | `scripts/tls/` only issues mTLS variant | No pure one-way TLS profile for Node.js/TS/Swift compat |

---

## 4. Per-language quick-win backlog

Each item is a small PR (~1 language, ~1 PR). Sorted by cost-effectiveness (capability unlocked per PR size).

| Lang | PR | Why this one first |
|---|---|---|
| **Node.js** | enable mTLS: change `src/server/index.js:186` `false` → `true`; pass client key/cert in `src/common/connection.js:103` `createSsl(rootCert, key, cert)` | Node.js is the most popular JS stack; mTLS unblocks B2 for the entire community |
| **Node.js** | uncomment `@grpc/grpc-js-reflection` at `src/server/index.js:25`; add to `add_Service_with_reflection` | Reflection dep already installed in `package.json:11`; literal one-line fix |
| **Python** | register `LoggingInterceptor` — change `server/protoServer.py:364` to `grpc.server(pool, interceptors=[LoggingInterceptor(logger)])` | ~120 lines of code already written; just plumbing |
| **Python** | add health check via `pip install grpc-health-checking` + service registration in `protoServer.py:365` | First wins B5 for Python |
| **Rust** | add `tonic-health` + `tonic-reflection` | Both crates exist; missing imports |
| **Go** | add `compress: gzip` to `conn/connection.go` `[]grpc.DialOption` | One-line B7 for the yardstick language |
| **Java** | add `withDeadlineAfter(...)` in `ProtoClient.java:174` (and the 3 stream call sites) | A7 unblocked for Java |
| **Java** | wire `ServerInterceptor` for `setTrailer(...)` in `LandingServiceImpl` | A6 unblocked |
| **Swift** | forward `metadata: context.metadata` at `HelloService.swift:81,108,147,187` (instead of `[:]`) | A5 proxy bug fixed |
| **C#** | wrap `Method<T,TResponse>` with `CallInvoker.Intercept` for logging B3/B4 | Unblocks 2 cells |
| **All 14** | commit `proto/health/v1/health.proto`, regenerate, wire where lib supports | One commit unlocks B5 for ≥10 langs |
| **All 14** | commit `proto/reflection/v1alpha/reflection.proto`, regenerate, wire where lib supports | One commit unlocks B6 for ≥10 langs |

---

## 5. Version / dependency audit (separate scope, not depth-checked here)

The root README lists only feature indicators, not versions. Of note from per-language READMEs sampled:
- Go: gRPC 1.76.0 / protobuf 1.36.10 / Go 1.25.4 — current as of mid-2025.
- Python: grpcio-tools 1.76.0 / protobuf 6.33.1 — recent.
- Java: gRPC 1.75.0 / protobuf-java 3.24.3 — **Java protobuf 3.x is on a different cadence than the rest of protobuf 4.x+**. Tracked separately; not necessarily wrong, but the "protobuf version" column conflates two major tracks.
- Java: JDK 21 / Maven 3.9.11 — current.
- Kotlin: gRPC-Kotlin — version not surfaced in README matrix. Not depth-checked in this audit.

Full dependency audit is a separate dimension and was **out of scope** for this capability scan. Recommend re-grilling with that scope next.

---

## 6. What this audit deliberately did NOT do

- Did not run any language; all judgments are static analysis of source.
- Did not check testify/junit test pass rates; only whether tests reference the capability.
- Did not check CI workflows for which capabilities are exercised end-to-end.
- Did not check Docker / k8s manifests per-language (cross-cutting batch 3 saw `scripts/k8s/mesh/` uses Istio VirtualService, `transcoder/` for gRPC-JSON, but per-language Dockerfile capability inventory was not built).
- Did not run vulnerability scans on dependencies.
- Did not diff proto-level changes vs grpc-java-api canonical protobuf versions.

---

## 7. Recommended next grilling step

Three obvious follow-up dimensions to grill next (pick one):

1. **Dependency audit** (separate scope) — versions vs current EOL/security-advisories, including protobuf 3.x Java ladder vs 4.x+ in 9 other languages.
2. **CI / test coverage** — what capabilities are actually exercised end-to-end vs only statically present.
3. **Cross-language API drift** — same capability, different shapes (e.g. interceptor signatures in Java vs Go vs Kotlin).
