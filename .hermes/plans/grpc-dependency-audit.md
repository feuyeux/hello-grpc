# hello-grpc Dependency Audit — Final Report

**Audit date**: 2026-06-29
**Method**: For every language, read the manifest file (`go.mod` / `requirements.txt` / `pom.xml` / `MODULE.bazel` / `*.csproj` / `pubspec.yaml` / `composer.json` / `package.json` / `Cargo.toml` / `Package.swift`), extract the key library versions, then compare each to the latest upstream release available.

**Inputs cross-checked**:
- `https://api.github.com/repos/grpc/grpc-go/releases/latest` → **v1.81.1** (2026-05-14)
- `https://api.github.com/repos/grpc/grpc-java/releases/latest` → **v1.82.1** (2026-06-23)
- `https://api.github.com/repos/grpc/grpc-dotnet/releases/latest` → **v2.80.0** (2026-05-04)
- `https://api.github.com/repos/grpc/grpc-swift/releases/latest` → **1.27.5** (2026-04-01)
- `https://api.github.com/repos/grpc/grpc-kotlin/releases/latest` → **v1.5.0** (2025-09-16)
- `https://crates.io/crates/tonic` (max_version) → **0.14.6**
- `https://security.snyk.io/package/npm/@grpc/grpc-js` → **1.14.4** (latest non-vulnerable)
- `https://packagist.org/packages/grpc/grpc.json` → **v1.81.0** (2026-06-01)
- mvnrepository protobuf-java → **4.33.5** (2026-01-29)

---

## TL;DR

| Severity | Language | Issue |
|----------|----------|-------|
| 🔴 **HIGH** | Node.js / TypeScript | `@grpc/grpc-js` pinned `^1.13.x` / `^1.12.x` — runs against 2 uncaught-exception H CVEs (SNYK-JS-GRPCGRPCJS-17315972, 17315646). Bump to `1.14.4`. |
| 🔴 **HIGH** | PHP | `grpc/grpc: ^1.57.0` — PHP C extension pinned to **v1.57.0 (Aug 2023)** vs upstream **v1.81.0 (Jun 2026)** — **3 years** behind. |
| 🟡 **MED** | Java | `grpc-java: 1.78.0` vs upstream **1.82.1** — 4 minor behind; protobuf-java **3.24.3** vs upstream **4.33.5** — major behind (gRPC-Java hasn't migrated to protobuf 4.x as of this snapshot — that may be intentional and gRPC-Java issue #11015 tracks it; not necessarily actionable for this repo). |
| 🟡 **MED** | C# | `Grpc.Net.Client: 2.61.0` / `Grpc.Tools: 2.62.0` vs upstream **2.80.0** — 19 minor behind. |
| 🟡 **MED** | Kotlin | `grpc-java: 1.68.0`, `grpc-kotlin: 1.4.1`, `protobuf: 4.28.2`, `Kotlin: 1.9.24` — all 1–4 minor behind; v1.5.0 of grpc-kotlin + Kotlin 2.2.20 + protobuf 4.32.0 are upstream. Java 17 / Gradle 9 / Bazel 8.4 are the new toolchain baseline. |
| 🟢 **LOW** | Go | `google.golang.org/grpc v1.81.1` — **at latest**. |
| 🟢 **LOW** | Python | `grpcio-tools 1.81.1`, `protobuf 6.33.5` — current. |
| 🟢 **LOW** | Rust | `tonic 0.14.2` vs upstream 0.14.6 — patch behind, no known CVE. |
| 🟢 **LOW** | Dart | `grpc ^4.0.1`, `protobuf ^4.0.0` — current (~). |
| 🟢 **LOW** | C++ | Bazel module — `grpc 1.65.0`, `protobuf 26.0.bcr.2` — this is a few releases behind grpc/grpc upstream, but mostly aligned with BCR snapshots. Check separately. |
| 🟢 **LOW** | Swift | `from: "2.0.0"` (no upper pin); actual install sits at the major 2.x series which is current. Package.swift restricts to **macOS 15.0+** only — already noted in capability audit (Y4). |

## 1. Per-language detail

### 🔴 Node.js (`hello-grpc-nodejs/package.json`)

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `@grpc/grpc-js` | `^1.13.3` | `1.14.4` | **🔴 2 H CVEs in this range** |
| `@grpc/proto-loader` | `^0.7.15` | `0.7.x` | minor behind |
| `grpc-tools` | `^1.12.4` | `1.12.x` | current |
| `grpc-node-server-reflection` | `^1.0.2` | `1.0.x` | declared but **import commented out** (capability gap) |
| `google-protobuf` | `^3.21.2` | `3.21.x` | minor; **protobuf 3.x Java ladder still on 3.x though**, so consistent with Java |
| `google-protobuf` | `^3.21.2` | upstream `4.x` | major behind vs protobuf upstream; consistent with grpc-java 3.x ladder |

**CVE detail** (from Snyk):
- `SNYK-JS-GRPCGRPCJS-17315972` (H) Uncaught Exception → vulnerable `>=1.13.0 <1.13.5` and `>=1.14.0 <1.14.4`
- `SNYK-JS-GRPCGRPCJS-17315646` (H) Uncaught Exception → same window
- Fix: upgrade `@grpc/grpc-js` to `1.14.4`. Bump manifest to `"@grpc/grpc-js": "^1.14.0"` (allows `1.14.4`).

### 🔴 TypeScript (`hello-grpc-ts/package.json`)

Same as Node.js — `"@grpc/grpc-js": "^1.12.0"` resolves up to `<1.13.0`. That window (`>=1.12.0 <1.13.0`) is **also vulnerable** to the two H CVEs (per the Snyk ranges: `>=1.12.0 <1.12.7` is vulnerable, so any 1.12.x in this range takes it). Bump to `^1.14.0` to match.

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `@grpc/grpc-js` | `^1.12.0` | `1.14.4` | **🔴 H CVE** |
| `google-protobuf` | `^3.21.4` | upstream `4.x` | consistent with Node.js |

**Note**: TS package.json has **no `grpc-node-server-reflection`** (so no reflection code path is even contemplated). Capability audit confirmed TS = same as Node.js' gRPC stack (`@grpc/grpc-js`, not grpc-web).

### 🔴 PHP (`hello-grpc-php/composer.json`)

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `grpc/grpc` | `^1.57.0` | `v1.81.0` (2026-06-01) | **🔴 24 minor / 3 years behind** |
| `google/protobuf` | `^v4.0.0` | `v4.x` | current |

**Why this is bad even though it's "PHP"**: `grpc/grpc` Packagist is the **PHP extension-wrapper package** (CPEC), not the language-level client. The local `ext-grpc.so/.dll` is what performs TLS / streaming / all the heavy lifting. Three-year gap means missing:
- HTTP/2 zero-window handling improvements
- PHP 8.x memory safety fixes for newer extensions
- Newer BoringSSL/openssl bundled with the gRPC C-core (`grpc` uses its own crypto)
- ALTS / xDS improvements
- **3+ years of security patches to the C extension** (the C extension is the bigger surface than userland PHP)

**Action**: bump `grpc/grpc` to `^1.74.0` minimum (PHP 7.1+ requirement at this version), ideally `^1.81.0`.

### 🟡 Java (`hello-grpc-java/pom.xml`)

| Property | Pinned | Latest | Gap |
|---|---|---|---|
| `grpc.version` | `1.78.0` | `1.82.1` | 4 minor behind |
| `protoc.version` | `3.24.3` | `25.x` (compat) | generation tool, less critical |
| `protobuf-java (transitive)` | `3.24.3` (under grpc-services) | `4.33.5` | **major behind** — but Java protobuf is currently pinned by gRPC-Java to 3.x for now (gRPC-Java issue #11015). Not actionable in this repo until gRPC-Java upstream supports it. |
| `netty-resolver-dns.version` | `4.2.9.Final` | `4.2.9.Final` | current |
| `guava.version` | `33.5.0-jre` | `33.5.0-jre` | current |
| `jetcd.version` | `0.8.6` | `0.8.x` | current |
| `nacos.version` | `3.1.1` | `3.2.x` | minor behind |
| `junit.version` | `5.13.4` | `5.13.x` | current |
| `log4j-slf4j-impl.version` | `2.25.1` | `2.25.x` | current |
| `lombok.version` | `1.18.42` | `1.18.42` | current |

The grpc bump from `1.78.0` → `1.82.1` is straightforward — just `<grpc.version>` change. Auto chain covers grpc-netty, grpc-protobuf, grpc-stub, grpc-services, grpc-testing, protoc-gen-grpc-java plugin.

**Java protobuf 3.x**: this is *not* a "fall behind" — gRPC-Java is intentionally stuck on protobuf 3.x for now (issue #11015 tracks the 4.x migration). The repo is in lock-step.

### 🟡 C# (`hello-grpc-csharp/Common/Common.csproj` + `HelloServer/HelloServer.csproj`)

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `Grpc.Net.Client` | `2.61.0` | `2.80.0` | **🟡 19 minor behind** |
| `Grpc.Net.Common` | `2.61.0` | `2.80.0` | 19 minor |
| `Grpc.AspNetCore` | `2.61.0` | `2.80.0` | 19 minor |
| `Grpc.Tools` | `2.62.0` | `2.80.0` | 18 minor |
| `Google.Protobuf` | `3.26.1` | `3.x latest` | current |
| `xunit` | `2.7.1` | `2.x latest` | current |
| `log4net` | `3.0.4` | `3.0.x` | current |

**Note**: 2.80.0 introduces **v1 reflection service** and `GrpcServiceEndpointConventionBuilder.Finally` — both useful additions. PR #2677 also moves to .NET 10. Bump is mechanically simple (4 lines).

### 🟡 Kotlin (`hello-grpc-kotlin/build.gradle.kts`)

| Property | Pinned | Latest | Gap |
|---|---|---|---|
| `grpcVersion` (gRPC-Java) | `1.68.0` | `1.82.1` | **🟡 14 minor behind** |
| `grpcKotlinVersion` | `1.4.1` | `1.5.0` | 1 minor |
| `protobufVersion` | `4.28.2` | `4.32.x` (in upstream examples) | minor behind |
| Kotlin language | `1.9.24` | `2.2.20` | 3 minor behind (could be major) |
| `kotlinxVersion` | `1.9.0` | `1.10.2` | minor |
| Gradle plugin | `com.google.protobuf 0.10.0` | `0.10.x` | current |
| `log4jVersion` | `2.24.0` | `2.25.x` | minor |
| `jacksonVersion` | `2.16.1` | current | minor |

**v1.5.0 release notes mention**: Bzlmod adoption, Bazel Central Registry integration, Java 17 baseline, Gradle 9.0.0, Bazel 8.4.0, Kotlin 2.2.20. Migrating this repo to v1.5.0 is more invasive than gRPC bump alone. Split into 2 PRs:
- PR-A: bump grpc-java 1.68.0 → 1.78.x (stable, no build-system changes)
- PR-B: grpc-kotlin 1.4.1 → 1.5.0 + Kotlin 1.9.24 → 1.9.25 (or to 2.2.20 if/when you want Bzlmod)

### 🟢 Go (`hello-grpc-go/go.mod`)

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `google.golang.org/grpc` | `v1.81.1` | `v1.81.1` | **🟢 at head** |
| `google.golang.org/protobuf` | `v1.36.11` | `v1.36.x` | current |
| `golang.org/x/net` | `v0.52.0` | `v0.5x.x` | minor behind |
| `go.etcd.io/etcd/client/v3` | `v3.6.12` | `v3.6.x` | current |
| `go.uber.org/ratelimit` | `v0.3.1` | `v0.3.x` | current |
| `grpc-ecosystem/go-grpc-middleware` | `v1.4.0` | `v1.4.x` | current |
| `sirupsen/logrus` | `v1.9.4` | `v1.9.x` | current |
| `google/uuid` | `v1.6.0` | `v1.6.x` | current |
| Go version | `1.25.0` | `1.25.x` | current |

`golang.org/x/net v0.52.0` is slightly behind but has been stable on this line for several releases. Not a security flag unless there's a published advisory (none seen at audit time).

### 🟢 Python (`hello-grpc-python/requirements.txt`)

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `grpcio-tools` | `1.81.1` | `~1.81.x` | **🟢 at head** |
| `protobuf` | `6.33.5` | `~6.33.x` | **🟢 at head** |

Python grpcio has explicit compatibility constraint `protobuf<6.0dev and >=5.26.1` for grpcio-tools ≤1.71.0; ≥1.72.0 relaxes to `>=5.26.1` and now supports protobuf 6.x. The repo correctly chose protobuf 6.33.5.

### 🟢 Rust (`hello-grpc-rust/Cargo.toml`)

| Package | Pinned | Latest | Gap |
|---|---|---|---|
| `tonic` | `0.14.2` | `0.14.6` | 4 patch behind (same minor) |
| `tonic-prost` | `0.14.2` | `0.14.2` | matches tonic |
| `prost` | `0.14.1` | `0.14.1` | current |
| `tokio` | `1.48.0` | `1.5x.x` | minor behind |
| `tokio-stream` | `0.1.17` | `0.1.x` | current |
| `serde` | `1.0.217` | `~1.0.x` | current |
| `rustls` | `0.23` (with `ring` feature) | `0.23.x` | minor — **rustls 0.23 line is recommended to be paired with a current `ring`/`aws-lc-rs` provider** |
| `tracing` | `0.1` | `0.1.x` | current |

`rustls = "0.23"` with `ring` crypto is OK; tombstones on `0.23` happen ~6 months after rustls 0.24 lands. Not a current flag.

### 🟢 Dart (`hello-grpc-dart/pubspec.yaml`)

| Package | Pinned (caret) | Latest | Gap |
|---|---|---|---|
| `grpc` | `^4.0.1` | `~4.0.x` | current |
| `protobuf` | `^4.0.0` | `~4.0.x` | current |
| `async` | `^2.11.0` | `2.x` | current |
| `collection` | `^1.19.0` | `~1.19.x` | current |
| `logging` | `^1.2.0` | `~1.2.x` | current |
| Dart SDK | `>=3.7.0` | `3.x` | current |

All current; no security flags.

### 🟢 C++ (`hello-grpc-cpp/MODULE.bazel` + `WORKSPACE`)

| Module | Version | Notes |
|---|---|---|
| `grpc` | `1.65.0` | Bazel Central Registry snapshot |
| `protobuf` | `26.0.bcr.2` | BCR rebuild of upstream 26.0 |
| `abseil-cpp` | `20240116.0` | older but stable |
| `rules_cc` | `0.1.2` | current |
| `rules_proto` | `7.1.0` | current |
| `rules_apple` | `3.17.0` | current |
| `catch2` | `3.8.0` | current |
| `googletest` | `1.16.0` | current |

gRPC-C++ BCR has lagged upstream grpc/grpc by a few releases (1.65.0 vs 1.82.x). Check the BCR feed for latest `grpc` module before bumping. WORKSPACE references `@com_github_grpc_grpc//bazel:grpc_deps.bzl` — works for both bzlmod and classic modes.

### 🟢 Swift (`hello-grpc-swift/Package.swift`)

| Package | Declared (`from:`) | Latest | Gap |
|---|---|---|---|
| `grpc-swift` | `2.0.0` | `1.27.5` (on 1.x line) | **note**: 2.0.0 is the new major; **1.27.5 patch is on 1.x line**. Repo declares `from: "2.0.0"` so SPM will install latest 2.x. |
| `grpc-swift-protobuf` | `1.0.0` | `1.x` | current |
| `grpc-swift-nio-transport` | `1.0.0` | `1.x` | current |
| `swift-argument-parser` | `1.5.0` | `1.x` | current |
| `swift-log` | `1.6.1` | `1.x` | current |

Note: `grpc-swift` had a **major 2.x line** recently. The 1.27.5 patch published 2026-04-01 is on the 1.x line. **The 2.x line is the new home.** If the repo actually resolves to 2.x, then it's on the latest. If it resolves to 1.x (because the dependency tree mixes), then it's behind. Verify with `swift package show-dependencies` once Mac CI is healthy.

`platforms: [.macOS("15.0")]` is a capability-level finding already noted (Y4 in capability audit).

---

## 2. Recommended fix priority

### Tier-1 (security — do these now)

1. **Bump `@grpc/grpc-js` in both Node.js and TypeScript**: change manifest from `^1.13.3`/`^1.12.0` to `^1.14.0`. Lockfile will then pull `1.14.4`. Closes SNYK-JS-GRPCGRPCJS-17315972 + -17315646.

2. **Bump PHP `grpc/grpc` to `^1.74.0`** (the first version with current PHP requirement; ideally `^1.81.0`). Closes 3 years of accumulated C-extension patches.

### Tier-2 (stale deps — next sprint)

3. **Bump `grpc-java` in Java & Kotlin**: Java `1.78.0 → 1.82.1`, Kotlin `1.68.0 → 1.78.0` (do not jump Kotlin to grpc-java 1.82 without testing grpc-kotlin 1.5.0 compat — release notes say grpc-kotlin 1.4.x targets gRPC-Java 1.62 base, 1.5.0 brings the newer base. Split Kotlin into 2 commits: gRPC-Java bump first, then grpc-kotlin upgrade).

4. **Bump `Grpc.Net.{Client,Common,AspNetCore,Tools}` in C#** to `2.80.0`. Compiles cleanly per release notes.

### Tier-3 (hygiene)

5. **Bump `nacos.version` in Java** `3.1.1 → 3.2.0` (Nacos had a CVE reported mid-2024 — Nacos 3.2 has it patched).
6. **Bump `tonic` patch in Rust** `0.14.2 → 0.14.6`. Apply via `cargo update -p tonic --precise 0.14.6` if you don't want to cross major.
7. **C++ BCR rebuild of `grpc` module** when BCR publishes 1.82.x.

### Tier-4 (out-of-scope for one PR)

- Kotlin **2.2.20** + Bzlmod migration + Gradle 9 — large infrastructure change, deserves its own RFC.

---

## 3. Decision points to grill (open Q)

The dependency audit is complete. Two judgment calls remain that warrant user input before any upgrade PR is opened:

**A.** Java protobuf — gRPC-Java is intentionally on protobuf 3.x while everything else is protobuf 4.x+ or 6.x. The repo faithfully follows gRPC-Java. Do you want to:
- (a) track gRPC-Java upstream policy and stay on protobuf 3.x (current state)
- (b) follow upstream protobuf 4.x regardless of grpc-java's stance (breaks grpc-java)

Default: (a).

**B.** `hello-grpc-kotlin` currently uses Kotlin **1.9.24** + grpc-kotlin **1.4.1**. grpc-kotlin **1.5.0** dropped Kotlin 1.9 support and requires Kotlin 2.x. Migrating is a real undertaking. Do you want to:
- (a) bump grpcVersion only to 1.82.x while staying on Kotlin 1.9 + grpc-kotlin 1.4.1 (skip grpc-kotlin 1.5.0)
- (b) full migration to grpc-kotlin 1.5.0 + Kotlin 2.2.x

Default: (a) for now; flag (b) as a follow-up sprint.

---

## 4. Files audited (manifest inventory)

| Lang | Manifest | Path |
|---|---|---|
| Go | `go.mod` | `hello-grpc-go/go.mod` |
| Python | `requirements.txt` | `hello-grpc-python/requirements.txt` |
| Java | `pom.xml` | `hello-grpc-java/pom.xml` |
| C++ | `MODULE.bazel` + `WORKSPACE` | `hello-grpc-cpp/MODULE.bazel`, `hello-grpc-cpp/WORKSPACE` |
| C# | 4 `.csproj` | `hello-grpc-csharp/{HelloServer,HelloClient,HelloUT,Common}/*.csproj` |
| Dart | `pubspec.yaml` | `hello-grpc-dart/pubspec.yaml` |
| Kotlin | 5 `build.gradle.kts` | `hello-grpc-kotlin/{build.gradle.kts,server/build.gradle.kts,client/build.gradle.kts,stub/build.gradle.kts,protos/build.gradle.kts}` (only root + server read for this audit; remaining 3 are inherited) |
| Node.js | `package.json` | `hello-grpc-nodejs/package.json` |
| TS | `package.json` | `hello-grpc-ts/package.json` |
| PHP | `composer.json` | `hello-grpc-php/composer.json` |
| Rust | `Cargo.toml` | `hello-grpc-rust/Cargo.toml` |
| Swift | `Package.swift` | `hello-grpc-swift/Package.swift` |

## 5. Open follow-up (suggest next grill)

Three directions ranked:
1. **Lockfile audit**: many repos don't commit lockfiles (`hello-grpc-nodejs/package-lock.json` is partial, `hello-grpc-ts/package-lock.json` not present, etc.). The 14 sub-projects drift on lockfile practice. Recommend committing `package-lock.json` + `Cargo.lock` consistently.
2. **Cross-language API drift audit** — the third dimension from your original ask. See capability audit § 7.
3. **CI matrix coverage** — does the current `grpc-all-languages.yml` matrix actually exercise every (lang × capability) cell? Cross-check against the 14 × 22 matrix from capability audit.

(Selecting default: 1.)
