package org.feuyeux.grpc

import io.grpc.ClientInterceptor
import io.grpc.ServerInterceptor
import io.opentelemetry.api.OpenTelemetry
import io.opentelemetry.api.common.AttributeKey
import io.opentelemetry.api.common.Attributes
import io.opentelemetry.api.metrics.LongCounter
import io.opentelemetry.api.metrics.Meter
import io.opentelemetry.api.trace.Tracer
import io.opentelemetry.exporter.logging.LoggingMetricExporter
import io.opentelemetry.exporter.logging.LoggingSpanExporter
import io.opentelemetry.instrumentation.grpc.v1_6.GrpcTelemetry
import io.opentelemetry.sdk.OpenTelemetrySdk
import io.opentelemetry.sdk.metrics.SdkMeterProvider
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader
import io.opentelemetry.sdk.resources.Resource
import io.opentelemetry.sdk.trace.SdkTracerProvider
import io.opentelemetry.sdk.trace.export.SimpleSpanProcessor
import io.opentelemetry.semconv.ResourceAttributes

/**
 * OpenTelemetry wiring for hello-grpc-kotlin.
 *
 * Mirrors the Go (PR #486), Python (#488), Node.js+TS (#489),
 * Rust (#490), C# (#491), C++ (#492), PHP (#493), Dart (#494),
 * and Java (#496) implementations. opt-in via GRPC_HELLO_OTEL=Y.
 *
 * Library choice mirrors the Java #496 PR:
 * io.opentelemetry.instrumentation:opentelemetry-grpc-1.6 provides
 * public GrpcTelemetry factory methods for io.grpc.ServerInterceptor /
 * ClientInterceptor implementations.
 */
object Otel {
    const val ENV_OTEL_ENABLED = "GRPC_HELLO_OTEL"

    fun enabled(): Boolean = System.getenv(ENV_OTEL_ENABLED) == "Y"

    @JvmStatic
    fun initOtel(serviceName: String): OpenTelemetry {
        if (!enabled()) return OpenTelemetry.noop()
        val resource: Resource = Resource.getDefault().merge(
            Resource.create(Attributes.of(ResourceAttributes.SERVICE_NAME, serviceName))
        )
        val tracerProvider = SdkTracerProvider.builder()
            .addSpanProcessor(SimpleSpanProcessor.create(LoggingSpanExporter.create()))
            .setResource(resource)
            .build()
        val meterProvider = SdkMeterProvider.builder()
            .registerMetricReader(PeriodicMetricReader.create(LoggingMetricExporter.create()))
            .setResource(resource)
            .build()
        return OpenTelemetrySdk.builder()
            .setTracerProvider(tracerProvider)
            .setMeterProvider(meterProvider)
            .build()
    }

    @JvmStatic
    fun serverInterceptor(openTelemetry: OpenTelemetry): ServerInterceptor? {
        if (!enabled()) return null
        val grpcTelemetry = GrpcTelemetry.builder(openTelemetry).build()
        return grpcTelemetry.newServerInterceptor()
    }

    @JvmStatic
    fun clientInterceptor(openTelemetry: OpenTelemetry): ClientInterceptor? {
        if (!enabled()) return null
        val grpcTelemetry = GrpcTelemetry.builder(openTelemetry).build()
        return grpcTelemetry.newClientInterceptor()
    }

    @JvmStatic
    fun tracer(openTelemetry: OpenTelemetry): Tracer =
        openTelemetry.getTracer("hello-grpc-kotlin")

    @JvmStatic
    fun meter(openTelemetry: OpenTelemetry): Meter =
        openTelemetry.getMeter("hello-grpc-kotlin")

    @JvmStatic
    fun rpcCallsCounter(openTelemetry: OpenTelemetry): LongCounter =
        meter(openTelemetry).counterBuilder("rpc_calls_total")
            .setDescription("Total number of gRPC calls handled")
            .setUnit("{call}")
            .build()

    @JvmStatic
    fun serviceNameKey(): AttributeKey<String> = ResourceAttributes.SERVICE_NAME
}
