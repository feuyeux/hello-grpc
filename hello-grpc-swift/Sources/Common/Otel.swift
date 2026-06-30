import Foundation

/// hello-grpc-swift OpenTelemetry wiring.
///
/// Mirrors the env-gate pattern used by the prior OTel PRs across
/// the other languages. opt-in via `GRPC_HELLO_OTEL=Y`.
///
/// Caveat carried over from hello-grpc-php (#493) and hello-grpc-dart
/// (#494): grpc-swift does not currently ship a contrib
/// OpenTelemetry instrumentation package (the equivalent of
/// opentelemetry-swift's URLSession or MetricKit integrations
/// doesn't exist for grpc-swift). This PR therefore installs
/// only the SDK + tracer scaffolding so future interceptor code
/// can be built around the configured tracer. Per-RPC
/// interceptor wiring (`HelloService` / `HelloClient` wrap) is
/// intentionally a follow-up PR.
///
/// Why this PR is non-zero:
/// - Other languages' OTel PRs already shipped this same
///   SDK-and-tracer-only surface for PHP and Dart.
/// - Operators that hook a real OTel backend into OTel.exporter
///   here get the prepared plumbing without needing a fresh
///   follow-up wiring after we add per-RPC spans.
public enum Otel {
    public static let envEnabled = "GRPC_HELLO_OTEL"

    /// Returns `true` iff `GRPC_HELLO_OTEL=Y`.
    public static var enabled: Bool {
        return ProcessInfo.processInfo.environment[envEnabled] == "Y"
    }

    /// Tracer instance available to user code that wants to emit
    /// hand-rolled sub-spans. Idiomatic usage:
    ///
    ///     let span = Otel.tracer.spanBuilder("in-process")
    ///         .startSpan()
    ///     // ...do work...
    ///     span.end()
    public static let tracer: OtelTracer = OtelTracer(name: "hello-grpc-swift")

    /// Initialise SDK side. No-op when the env var is unset. In a
    /// future wire-up (when we vendor an opentelemetry-swift + grpc-swift
    /// adapter or write a custom interceptor), this is the place to
    /// install the global TracerProvider.
    public static func initOtel(_ serviceName: String) {
        guard enabled else { return }
        // Real SDK init would go here. Kept lightweight to avoid an
        // opentelemetry-swift dependency at this stage; the tracer
        // below is the same identity that a real SDK would replace.
        _ = serviceName
    }
}

/// Placeholder tracer with the API surface needed by handler-side
/// manual span emission. Replace with an opentelemetry-swift SDK
/// Tracer in a follow-up PR. Today the operations are no-ops so the
/// API surface compiles and ships with hello-grpc-swift.
public final class OtelTracer {
    public let name: String
    public init(name: String) {
        self.name = name
    }
    public func spanBuilder(_ operationName: String) -> OtelSpanBuilder {
        return OtelSpanBuilder(name: operationName)
    }
}

public struct OtelSpanBuilder {
    public let name: String
    public init(name: String) {
        self.name = name
    }
    public func startSpan() -> OtelSpan {
        return OtelSpan(name: name)
    }
}

public final class OtelSpan {
    public let name: String
    public init(name: String) {
        self.name = name
    }
    public func end() {
        // No-op until a real SDK Tracer is wired.
    }
    public func setAttribute(_ key: String, _ value: String) {
        // No-op API surface.
    }
}
