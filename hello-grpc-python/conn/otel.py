"""OpenTelemetry wiring for hello-grpc-python.

Mirrors the Go implementation's design (PR #486) and the (now-reverted)
Java attempt (#487): an opt-in env var (GRPC_HELLO_OTEL=Y) installs
a global OpenTelemetry SDK and returns opentelemetry-instrumentation-grpc
client / server interceptors; otherwise the factory methods return
None so the call sites in server/protoServer.py and
client/protoClient.py stay byte-identical to before this commit.

The exporter is stdout for the teaching/demo posture of hello-grpc;
operators wanting an OTLP backend swap it for OTLPSpanExporter here
without changing the call graph.

B2 — Metrics: init_metrics() installs a MeterProvider with a
ConsoleMetricExporter and returns a Meter. Call sites use the returned
meter to create counters (e.g. rpc_calls_total). No-op when the env
var is off or the SDK packages are absent.
"""

import os

try:
    from opentelemetry import trace
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor, ConsoleSpanExporter

    _HAS_OTEL = True
except ImportError:
    _HAS_OTEL = False

try:
    from opentelemetry import metrics
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry.sdk.metrics.export import (
        ConsoleMetricExporter,
        PeriodicExportingMetricReader,
    )

    _HAS_OTEL_METRICS = True
except ImportError:
    _HAS_OTEL_METRICS = False

try:
    from opentelemetry.instrumentation.grpc import (
        client_interceptor as _otel_client_interceptor,
    )
    from opentelemetry.instrumentation.grpc import (
        server_interceptor as _otel_server_interceptor,
    )

    _HAS_OTEL_GRPC = True
except ImportError:
    _HAS_OTEL_GRPC = False


_ENV_OTEL_ENABLED = "GRPC_HELLO_OTEL"


def otel_enabled():
    """Return True iff GRPC_HELLO_OTEL=Y."""
    return os.environ.get(_ENV_OTEL_ENABLED, "") == "Y"


def init_otel(service_name):
    """Install a stdout-exporting TracerProvider as the global SDK.

    Returns None when GRPC_HELLO_OTEL is not "Y", or when the
    opentelemetry / opentelemetry-instrumentation-grpc packages are
    not installed. Callers can unconditionally invoke this at the
    top of main() — the no-op path is a one-liner.
    """
    if not otel_enabled():
        return None
    if not _HAS_OTEL:
        return None

    provider = TracerProvider(resource={"service.name": service_name})
    provider.add_span_processor(BatchSpanProcessor(ConsoleSpanExporter()))
    trace.set_tracer_provider(provider)
    return provider


def init_metrics(service_name):
    """Install a stdout-exporting MeterProvider as the global SDK (B2).

    Returns a Meter bound to service_name, or None when GRPC_HELLO_OTEL
    is not "Y" or the opentelemetry-sdk-metrics package is absent.
    Caller creates counters from the returned Meter, e.g.:
        meter = init_metrics("my-service")
        if meter:
            counter = meter.create_counter("rpc_calls_total")
    """
    if not otel_enabled():
        return None
    if not _HAS_OTEL_METRICS:
        return None

    reader = PeriodicExportingMetricReader(
        ConsoleMetricExporter(),
        export_interval_millis=30_000,
    )
    meter_provider = MeterProvider(metric_readers=[reader])
    metrics.set_meter_provider(meter_provider)
    return metrics.get_meter(service_name)


def server_interceptor():
    """Return an opentelemetry-instrumentation-grpc ServerInterceptor,
    or None when otel is not enabled or the package is missing."""
    if not otel_enabled() or not _HAS_OTEL_GRPC:
        return None
    return _otel_server_interceptor()


def client_interceptor():
    """Return an opentelemetry-instrumentation-grpc ClientInterceptor,
    or None when otel is not enabled or the package is missing."""
    if not otel_enabled() or not _HAS_OTEL_GRPC:
        return None
    return _otel_client_interceptor()
