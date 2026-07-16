//! hello-grpc-rust OpenTelemetry wiring.
//!
//! Mirrors the Go (#486), Python (#488), and Node.js/TS (#489) gates.
//! opt-in via `GRPC_HELLO_OTEL=Y`. When unset, `init_otel` is a no-op
//! and tonic's existing `tracing` instrumentation is untouched.
//!
//! The exporter is stdout (`opentelemetry-stdout`) so spans show up
//! without a sidecar Jaeger / OTLP collector. Operators wanting an
//! OTLP backend swap in `opentelemetry-otlp` here without changing
//! the call sites in server.rs / client.rs.

use opentelemetry::trace::TracerProvider as _;
use opentelemetry_sdk::Resource;
use opentelemetry_sdk::trace::{Sampler, TracerProvider};
use opentelemetry_semantic_conventions::resource::SERVICE_NAME;
use tracing_subscriber::{EnvFilter, prelude::*};

/// Returns true iff `GRPC_HELLO_OTEL=Y`.
pub fn otel_enabled() -> bool {
    std::env::var("GRPC_HELLO_OTEL")
        .map(|v| v == "Y")
        .unwrap_or(false)
}

/// Creates a `tracing::Span` carrying the gRPC semantic-convention
/// attributes (`rpc.system`, `rpc.method`, `rpc.service`).
///
/// The `tracing-opentelemetry` bridge will forward these fields as OTel
/// span attributes when `GRPC_HELLO_OTEL=Y` is set.  When OTel is
/// disabled the returned span is a no-op (entered but never exported).
///
/// # Example
/// ```rust
/// let _guard = hello_grpc_rust::otel::span_with_rpc_attrs("Talk", "LandingService").entered();
/// ```
pub fn span_with_rpc_attrs(method: &str, service: &str) -> tracing::Span {
    tracing::info_span!(
        "grpc_handler",
        rpc.system = "grpc",
        rpc.method = %method,
        rpc.service = %service,
    )
}

/// One-time OTel SDK + tracing-subscriber wiring. Idempotent: a second
/// call (e.g. when invoked from both server and client mains) returns
/// without making further changes.
pub fn init_otel(service_name: &'static str) {
    if !otel_enabled() {
        return;
    }
    static INIT: std::sync::Once = std::sync::Once::new();
    INIT.call_once(|| {
        let exporter = opentelemetry_stdout::SpanExporter::default();
        let provider = TracerProvider::builder()
            .with_resource(Resource::new([opentelemetry::KeyValue::new(
                SERVICE_NAME,
                service_name,
            )]))
            .with_sampler(Sampler::AlwaysOn)
            .with_simple_exporter(exporter)
            .build();
        let tracer = provider.tracer("hello-grpc-rust");
        // Bridge tonic's tracing -> OTel spans. Without this layer,
        // tonic emits tracing events but they go nowhere.
        let layer = tracing_opentelemetry::layer().with_tracer(tracer);
        tracing_subscriber::registry()
            .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
            .with(layer)
            .init();
    });
}
