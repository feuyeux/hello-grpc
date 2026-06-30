package org.feuyeux.grpc.common;

import io.grpc.ClientInterceptor;
import io.grpc.ServerInterceptor;
import io.grpc.opentelemetry.GrpcOpenTelemetry;
import io.grpc.opentelemetry.OpenTelemetryServerInterceptor;
import io.grpc.opentelemetry.OpenTelemetryClientInterceptor;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.exporter.logging.LoggingSpanExporter;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.SimpleSpanProcessor;
import io.opentelemetry.semconv.ResourceAttributes;

/**
 * OpenTelemetry wiring for hello-grpc-java.
 *
 * <p>Mirrors the Go implementation's design: an opt-in env var
 * ({@code GRPC_HELLO_OTEL=Y}) installs a global {@link OpenTelemetry}
 * provider and returns the grpc-java OTel interceptors; otherwise the
 * factory methods return {@code null} so the call sites in
 * {@code ProtoServer} and {@code ProtoClient} stay byte-identical
 * to the pre-OTel paths.
 *
 * <p>The exporter is {@link LoggingSpanExporter} for the same teaching/
 * demo posture as the Go side — operators wanting an OTLP backend
 * swap it for {@code OtlpGrpcSpanExporter} here without changing
 * anything else in the call graph.
 */
public final class OtelSupport {
    public static final String ENV_OTEL_ENABLED = "GRPC_HELLO_OTEL";

    private OtelSupport() {}

    public static boolean otelEnabled() {
        return "Y".equals(System.getenv(ENV_OTEL_ENABLED));
    }

    /**
     * Install a logging-exporter-backed TracerProvider as the global
     * OpenTelemetry SDK and return the same SDK so callers can pass it
     * through to {@link GrpcOpenTelemetry}. Returns a no-op SDK (the
     * default {@code OpenTelemetry#noop()}) when the env var is off,
     * so the deferred call at main is always safe to make.
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
     * Returns the grpc-java {@link ServerInterceptor} for OTel tracing
     * (or {@code null} if the env var is off). Caller chains it onto
     * the service via {@code ServerInterceptors.intercept(...)}.
     */
    public static ServerInterceptor serverInterceptor(OpenTelemetry openTelemetry) {
        if (!otelEnabled()) {
            return null;
        }
        return OpenTelemetryServerInterceptor.create(new GrpcOpenTelemetry.Builder()
                .sdk(openTelemetry)
                .build());
    }

    /**
     * Returns the grpc-java {@link ClientInterceptor} for OTel tracing
     * (or {@code null} if the env var is off). Caller chains it via
     * {@code ClientInterceptors.intercept(channel, ...)}.
     */
    public static ClientInterceptor clientInterceptor(OpenTelemetry openTelemetry) {
        if (!otelEnabled()) {
            return null;
        }
        return OpenTelemetryClientInterceptor.create(new GrpcOpenTelemetry.Builder()
                .sdk(openTelemetry)
                .build());
    }
}
