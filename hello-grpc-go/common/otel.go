package common

import (
	"context"
	"fmt"
	"os"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/stdout/stdouttrace"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.26.0"

	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"google.golang.org/grpc/stats"
)

// envOtelEnabled is the env-var gate matching the existing repo
// convention (GRPC_HELLO_SECURE, GRPC_HELLO_ETCD_ENDPOINTS, etc.).
const envOtelEnabled = "GRPC_HELLO_OTEL"

// OtelEnabled reports whether GRPC_HELLO_OTEL is set to "Y". Used by
// callers that want to initialize the global TracerProvider only when
// otel is active.
func OtelEnabled() bool {
	return os.Getenv(envOtelEnabled) == "Y"
}

// InitOtel installs a stdout-exporting TracerProvider as the global so
// the otelgrpc stats handlers pick it up at grpc.NewServer / grpc.Dial
// time. Returns a no-op shutdown when GRPC_HELLO_OTEL is not "Y", so
// the deferred call at main is always safe.
//
// The exporter is stdout for hello-grpc's teaching/demo posture: no
// external collector is required to observe the spans. Operators
// wanting an OTLP backend should swap the exporter for
// otel/otlptracehttp (or the grpc variant) in a follow-up without
// changing the call sites below.
func InitOtel(ctx context.Context, serviceName string) (shutdown func(context.Context) error, err error) {
	if !OtelEnabled() {
		return func(context.Context) error { return nil }, nil
	}

	exporter, err := stdouttrace.New(stdouttrace.WithPrettyPrint())
	if err != nil {
		return nil, fmt.Errorf("stdouttrace.New: %w", err)
	}

	res, err := resource.New(ctx,
		resource.WithAttributes(
			semconv.ServiceName(serviceName),
		),
	)
	if err != nil {
		return nil, fmt.Errorf("resource.New: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))
	return tp.Shutdown, nil
}

// OtelInterceptors returns the otelgrpc server- and client-side stats
// handlers as the grpc.StatsHandler interface. Returns nil for both
// when GRPC_HELLO_OTEL is not "Y" so callers can pass the result to
// grpc.WithStatsHandler(...) without conditional plumbing.
//
// otelgrpc v0.69+ (the only currently-published version) replaced the
// older UnaryServerInterceptor / UnaryClientInterceptor APIs with a
// single grpc.StatsHandler that instruments unary, stream, and metrics
// in one place. The handlers here cover both directions and all four
// streaming shapes.
func OtelInterceptors() (server stats.Handler, client stats.Handler) {
	if !OtelEnabled() {
		return nil, nil
	}
	return otelgrpc.NewServerHandler(), otelgrpc.NewClientHandler()
}
