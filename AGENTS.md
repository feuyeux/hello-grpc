# Repository Guidelines

## Project Structure & Module Organization

This repository contains matching gRPC examples across multiple languages. Shared protobuf definitions live in `proto/`, with backups in `proto_bk/`. Each implementation is isolated in a `hello-grpc-*` directory, for example `hello-grpc-java/`, `hello-grpc-go/`, `hello-grpc-python/`, `hello-grpc-ts/`, `hello-grpc-swift/`, and `hello-grpc-php/`. Language projects usually contain `client`, `server`, `common` or `conn` modules plus local `scripts/`. Docker assets are in `docker/`; Kubernetes, proxy, TLS, mesh, and tracing examples are under `scripts/`; diagrams and background notes are in `doc/`.

## Build, Test, and Development Commands

Most language projects expose the same script pattern:

```sh
cd hello-grpc-python && ./scripts/build.sh
cd hello-grpc-go && ./scripts/server_start.sh
cd hello-grpc-ts && npm test
```

Use the native tool when a script is clearer: `mvn test` in `hello-grpc-java`, `go test ./...` in `hello-grpc-go`, `cargo test` in `hello-grpc-rust`, `swift test` in `hello-grpc-swift`, `dart test` in `hello-grpc-dart`, and `composer test` or `vendor/bin/phpunit` in `hello-grpc-php`. Run `scripts/check-versions.sh` when validating local gRPC/protobuf tooling.

## Windows Local Toolchain

The primary local development environment for this workspace is Windows 11 (`windows/amd64`). Prefer PowerShell commands. In this Codex runtime, prefix shell commands with `rtk`; for PowerShell cmdlets, use `rtk proxy powershell -NoProfile -Command '...'`.

Current Windows toolchain snapshot:

| Language | Local toolchain | Windows verification command |
|---|---|---|
| C++ | Bazel `7.3.2`, CMake `4.3.3`, protoc `28.2` | `cd hello-grpc-cpp; bazel build //:hello_client //:hello_server` |
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
| PHP | PHP `8.5.7` from WinGet, Composer `2.9.7` | `cd hello-grpc-php; composer validate --strict; composer check-platform-reqs; vendor\bin\phpunit.bat` |

Current Windows PATH locations:

| Toolchain | PATH entry or executable resolved locally |
|---|---|
| C++ / protobuf | `D:\zoo\bin\bazel.exe`; `D:\Program Files\CMake\bin\cmake.exe`; `D:\zoo\bin\protoc.exe` |
| Rust | `C:\Users\feuye\.cargo\bin\rustc.exe`; `C:\Users\feuye\.cargo\bin\cargo.exe` |
| Java / Maven | `C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin\java.exe`; `D:\zoo\apache-maven-3.9.7\bin\mvn.cmd` |
| Go | `C:\Program Files\Go\bin\go.exe`; user binaries in `C:\Users\feuye\go\bin` |
| C# / .NET | `C:\Program Files\dotnet\dotnet.exe`; additional user SDK path `C:\Users\feuye\Tools\dotnet` |
| Python | `C:\Users\feuye\AppData\Local\Programs\Python\Python314\python.exe`; scripts in `C:\Users\feuye\AppData\Local\Programs\Python\Python314\Scripts`; launcher in `C:\Users\feuye\AppData\Local\Programs\Python\Launcher` |
| Node.js / npm / Yarn | `C:\Program Files\nodejs\node.exe`; npm and Yarn shims in `C:\Users\feuye\AppData\Roaming\npm` |
| Dart | `D:\zoo\flutter\bin\dart.bat` |
| Kotlin / Gradle | `D:\zoo\gradle-9.3.1\bin\gradle.bat`; older `D:\zoo\gradle-8.10.2\bin` may also appear earlier in PATH snapshots |
| Swift | `C:\Users\feuye\AppData\Local\Programs\Swift\Toolchains\6.3.2+Asserts\usr\bin\swift.exe`; runtime path `C:\Users\feuye\AppData\Local\Programs\Swift\Runtimes\6.3.2\usr\bin`; developer tools in `D:\zoo\swift\Library\Developer\Tools` |
| PHP / Composer | Composer shim at `C:\ProgramData\ComposerSetup\bin\composer.bat`; expected PHP path should be verified locally before running PHP tests |

Windows-specific notes:

- C++: `hello-grpc-cpp` uses Bazel with Bzlmod (MODULE.bazel). Three Windows build fixes: (1) the legacy `WORKSPACE` is renamed `WORKSPACE.bzlmod-off` because its `grpc_deps()`/`grpc_extra_deps()` calls create `rules_python` circular dependencies when loaded alongside MODULE.bazel; (2) native OpenTelemetry (`opentelemetry-cpp`) is disabled — every BCR version (1.19.0-1.27.0) conflicts with the resolved grpc@1.66.0 — and `common/otel.cc` is an env-gated no-op stub (honors `GRPC_HELLO_OTEL=Y`, logs SDK-unavailable) so server/client sources compile unchanged (the `@io_opentelemetry_cpp` deps + `grpc++_otel_plugin` are commented in `common/BUILD.bazel`); (3) `rules_proto` is pinned to 6.0.2 (7.1.0 forces `protobuf@29.1` whose host protoc segfaults) and `protos/BUILD.bazel` exposes a `system_protoc` genrule + `proto_lang_toolchain` so `.bazelrc.user` sets `--proto_compiler=//protos:system_protoc`/`--proto_toolchain_for_cc=//protos:system_cc_toolchain` to use `D:\zoo\bin\protoc27.2.exe` instead of the self-built (crashing) host protoc. **Remaining upstream blocker:** the self-built protobuf 27.0 host protoc crashes on Windows (Exit 0xC0000005 / LNK1181), and any non-27.0 system protoc emits a `#if PROTOBUF_VERSION != <protoc-version>` guard in generated `.pb.h` that fails the 27.0 library headers' version-safety `#error` (C1189), so the protobuf well-known `[for tool]` C++ compiles fail without an exactly-matching 27.0 protoc binary. This needs protobuf/MSVC-toolchain resolution upstream; the 3-hour `api_proto [for tool]` deadlock is resolved and most targets compile.
- Java/Kotlin: the current Windows JDK is newer than the Java 21 baseline used by the repo. Treat Java 21 compatibility as the source target unless the language project explicitly updates it.
- Python: `where.exe python` may list the WindowsApps execution alias before `Python314`; use the full `Python314\python.exe` path or fix PATH order when an exact interpreter matters.
- Node.js/TypeScript: prefer the package manager already used by the language directory. Do not mix npm and Yarn lockfile updates unless the project already does.
- Swift: the installed Windows Swift toolchain is `6.3.2` with assertions enabled. Two Windows toolchain/SwiftPM blockers have been fixed: (1) `swift-nio-ssl` is pinned to `>= 2.37.1` (direct dependency in `Package.swift`) which adds the `_WINSOCKAPI_`/`NOMINMAX`/`NOCRYPT` defines for `CNIOBoringSSL`; (2) because SwiftPM's `.when(platforms:[.windows])` conditional was not emitting those defines in this project (pinned to `.macOS` platform), the resolved checkout's `Package.swift` is additionally patched to define `WIN32_LEAN_AND_MEAN` unconditionally for `CNIOBoringSSL` — this is the robust guard that keeps `<windows.h>` from pulling in the conflicting legacy `<winsock.h>`. With these fixes the SwiftPM dependency scanner/resolver now passes cleanly (`swift package describe` succeeds) and the C BoringSSL sources compile. A remaining build failure is an **upstream limitation, not a toolchain/scanner issue**: `grpc-swift` (resolved at 2.2.3, also true on `main`) has `#error("Unsupported OS")` in `Sources/GRPCCore/Call/Client/Internal/RetryDelaySequence.swift` because its `#if canImport(...)` chain covers Darwin/Android/Glibc/Musl but not Windows; `swift build` cannot complete until grpc-swift adds Windows support upstream. SwiftPM may still report internal dependency scanner or malformed target-info errors on Windows; distinguish those toolchain failures from project source failures.
- PHP: prefer the WinGet PHP path before older manual installs such as `D:\zoo\php-*`. Current PATH snapshots may still contain stale PHP directories, for example `D:\zoo\php-8.3.12`, so confirm `where.exe php` before running PHP tests. `php.ini` enables the extensions needed for Composer and PHPUnit (`openssl`, `mbstring`, `zip`, `fileinfo`; other extensions may be enabled locally). Native `grpc` may be absent, so `grpc.version` can report `unknown`; Composer and PHPUnit can still pass because this project uses the Composer `grpc/grpc` package. If Composer exits with a Windows access violation, retry with a minimal extension set or temporarily disable nonessential extensions such as `curl`, `intl`, and `sodium`.

## Coding Style & Naming Conventions

Follow each language ecosystem and the existing file style. Java uses Java 21 with Maven and `fmt-maven-plugin`; TypeScript uses strict `tsconfig.json`; Dart uses `analysis_options.yaml`; Swift follows Swift Package Manager layout; C++ uses Bazel. Keep generated protobuf outputs in the owning language project and avoid hand-editing generated `*_pb*`, `.pb.go`, `.pb.swift`, or similar files. Preserve existing naming: `ProtoServer`, `ProtoClient`, `HelloService`, `Connection`, `ErrorMapper`, and `LoggingConfig` equivalents across languages.

## Testing Guidelines

Add tests beside the implementation in the language's standard test directory: `src/test`, `tests`, `test`, or `Tests`. Name tests after behavior, such as `HelloServiceTests`, `VersionTests`, `utils.test.ts`, or `proto_service_test.go`. For cross-language behavior changes, update at least the affected implementation and run its local test command.

## Commit & Pull Request Guidelines

Recent commits use Conventional Commits with scopes, for example `feat(swift): complete OTel per-RPC span wiring`. Use concise subjects like `fix(go): map grpc errors consistently`. Pull requests should describe the affected language(s), commands run, generated proto updates, and any Docker or Kubernetes impact. Link issues when applicable and include logs or screenshots only for user-visible behavior.

## Security & Configuration Tips

Do not commit private keys outside existing demo TLS material. Tracing is opt-in via `GRPC_HELLO_OTEL=Y`; keep default runtime behavior unchanged unless the change explicitly targets observability.
