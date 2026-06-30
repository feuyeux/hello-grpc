import Foundation
import GRPCCore
import OpenTelemetryApi
import OpenTelemetrySdk
import StdoutExporter

/// hello-grpc-swift OpenTelemetry wiring.
///
/// Mirrors the env-gate pattern used by the prior OTel PRs across
/// the other languages. opt-in via `GRPC_HELLO_OTEL=Y`.
public enum Otel {
    public static let envEnabled = "GRPC_HELLO_OTEL"

    /// Returns `true` iff `GRPC_HELLO_OTEL=Y`.
    public static var enabled: Bool {
        return ProcessInfo.processInfo.environment[envEnabled] == "Y"
    }

    private static let lock = NSLock()
    private static var _initialized = false

    /// One-time SDK setup. No-op when the env var is unset.
    public static func initOtel(_ serviceName: String) {
        guard enabled else { return }
        lock.lock()
        defer { lock.unlock() }
        guard !_initialized else { return }
        _initialized = true

        let exporter = StdoutExporter()
        let processor = SimpleSpanProcessor(spanExporter: exporter)
        let resource = DefaultResources.get().merging(
            with: Resource(attributes: [
                "service.name": AttributeValue(serviceName),
            ])
        )

        OpenTelemetry.registerTracerProvider(
            tracerProvider: TracerProviderBuilder()
                .add(spanProcessor: processor)
                .with(resource: resource)
                .build()
        )
    }

    /// Global tracer from the configured provider, or the no-op tracer.
    public static var tracer: Tracer {
        return OpenTelemetry.instance.tracerProvider.get(
            instrumentationName: "hello-grpc-swift"
        )
    }

    /// Starts a span with rpc.system/grpc attributes if OTel is enabled.
    public static func startSpan(
        _ name: String,
        kind: SpanKind = .internal
    ) -> Span? {
        guard enabled else { return nil }
        return tracer.spanBuilder(spanName: name)
            .setSpanKind(kind)
            .setAttribute(key: "rpc.system", value: "grpc")
            .setAttribute(key: "rpc.method", value: name)
            .startSpan()
    }
}

/// gRPC Swift 2.x server interceptor that emits an inbound [SpanKind.server] span
/// around each RPC.
public struct HelloServerInterceptor: ServerInterceptor, Sendable {
    public init() {}

    public func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingServerRequest<Input>,
        context: ServerContext,
        next: @Sendable (
            _ request: StreamingServerRequest<Input>,
            _ context: ServerContext
        ) async throws -> StreamingServerResponse<Output>
    ) async throws -> StreamingServerResponse<Output> {
        guard let span = Otel.startSpan(context.descriptor.fullName, kind: .server)
        else {
            return try await next(request, context)
        }

        defer { span.end() }

        do {
            return try await next(request, context)
        } catch {
            span.setStatus(.error, description: String(describing: error))
            throw error
        }
    }
}

/// gRPC Swift 2.x client interceptor that emits an outbound [SpanKind.client] span
/// around each RPC.
public struct HelloClientInterceptor: ClientInterceptor, Sendable {
    public init() {}

    public func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingClientRequest<Input>,
        context: ClientContext,
        next: @Sendable (
            _ request: StreamingClientRequest<Input>,
            _ context: ClientContext
        ) async throws -> StreamingClientResponse<Output>
    ) async throws -> StreamingClientResponse<Output> {
        guard let span = Otel.startSpan(context.descriptor.fullName, kind: .client)
        else {
            return try await next(request, context)
        }

        defer { span.end() }

        do {
            return try await next(request, context)
        } catch {
            span.setStatus(.error, description: String(describing: error))
            throw error
        }
    }
}
