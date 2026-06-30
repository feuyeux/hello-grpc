package org.feuyeux.grpc.common;

import io.grpc.ClientInterceptor;
import io.grpc.ServerInterceptor;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.exporter.logging.LoggingSpanExporter;
import io.opentelemetry.instrumentation.grpc.v1_6.GrpcTelemetry;
import io.opentelemetry.instrumentation.grpc.v1_6.TracingClientInterceptor;
import io.opentelemetry.instrumentation.grpc.v1_6.TracingServerInterceptor;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.SimpleSpanProcessor;
import io.opentelemetry.semconv.ResourceAttributes;

/**
 * OpenTelemetry wiring for hello-grpc-java.
 *
 * <p>Mirrors the Go (PR #486), Python (#488), Node.js+TS (#489),
 * Rust (#490), C# (#491), C++ (#492), PHP (#493), and Dart (#494)
 * implementations. An opt-in env var (GRPC_HELLO_OTEL=Y) installs
 * a global OpenTelemetry SDK + tracer provider and returns
 * {@code io.grpc.ServerInterceptor} /
 * {@code io.grpc.ClientInterceptor} implementations
 * ({@code TracingServerInterceptor} /
 * {@code TracingClientInterceptor} from
 * {@code io.opentelemetry.instrumentation:grpc-1.6}). When the env
 * var is unset the factory methods return {@code null} so callers
 * stay byte-identical to the pre-OTel path.
 *
 * <p>Note on library choice (vs. the reverted PR #487): the original
 * attempt used classes from {@code io.grpc:grpc-opentelemetry} that
 * do not exist in grpc-java 1.78 or 1.82.x — verified by downloading
 * the sources jar and inspecting class names. The
 * {@code io.opentelemetry.instrumentation:opentelemetry-grpc-1.6}
 * contrib library exposes a stable public interceptor API that
 * works against any grpc-java 1.6+ runtime.
 */
public final class OtelSupport {
    public static final String ENV_OTEL_ENABLED = "GRPC_HELLO_OTEL";

    private OtelSupport() {}

    public static boolean otelEnabled() {
        return "Y".equals(System.getenv(ENV_OTEL_ENABLED));
    }

    /**
     * Install a logging-exporter-backed TracerProvider as the global
     * SDK and return the same SDK so callers can pass it through to
     * GrpcTelemetry.builder(). Returns a no-op SDK
     * (OpenTelemetry.noop()) when the env var is off, so the
     * deferred call at main is always safe.
     */
    public static OpenTelemetry initOtel(String serviceName) {
        if (!otelEnabled()) {
            return OpenTelemetry.noop();
        }
        Resource resource = Resource.getDefault()
                .merge(Resource.create(Attributes.of(
                        ResourceAttributes.SERVICE_NAME, serviceName)));
        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
                .addSpanProcessor(SimpleSpanProcessor.create(LoggingSpanExporter.create()))
                .setResource(resource)
                .build();
        return OpenTelemetrySdk.builder()
                .setTracerProvider(tracerProvider)
                .build();
    }

    /**
     * Returns the OpenTelemetry {@code TracingServerInterceptor}
     * (or {@code null} when OTel is off). Caller wraps a
     * {@code ServerServiceDefinition} via {@code ServerInterceptors.intercept(...)}.
     */
    public static ServerInterceptor serverInterceptor(OpenTelemetry openTelemetry) {
        if (!otelEnabled()) {
            return null;
        }
        GrpcTelemetry grpcTelemetry = GrpcTelemetry.builder(openTelemetry).build();
        return new TracingServerInterceptor(grpcTelemetry);
    }

    /**
     * Returns the OpenTelemetry {@code TracingClientInterceptor}
     * (or {@code null} when OTel is off). Caller chains it via
     * {@code ClientInterceptors.intercept(channel, ...)}.
     */
    public static ClientInterceptor clientInterceptor(OpenTelemetry openTelemetry) {
        if (!otelEnabled()) {
            return null;
        }
        GrpcTelemetry grpcTelemetry = GrpcTelemetry.builder(openTelemetry).build();
        return new TracingClientInterceptor(grpcTelemetry);
    }

    /** Force the Tracer to be available globally so any service-side
     *  manual span emission has a configured tracer to use. */
    public static Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer("hello-grpc-java");
    }

    /** Marker onAttribute() re-export to avoid breaking the ResourceAttributes
     *  AttributeKey API surface for callers. */
    public static AttributeKey<String> serviceNameKey() {
        return ResourceAttributes.SERVICE_NAME;
    }
}
