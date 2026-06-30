// hello-grpc-cpp OpenTelemetry wiring.
//
// Mirrors the env-gate pattern used by the Go (#486), Python (#488),
// Node.js/TS (#489), Rust (#490), and C# (#491) implementations:
// GRPC_HELLO_OTEL=Y installs a stdout-exporting OpenTelemetry tracer
// provider. When the env var is unset the helper is a no-op and the
// existing server construction path is preserved.
//
// The full OTLP backend swap is documented inline.

#pragma once

#include <string>

namespace otel {

// Install the OpenTelemetry SDK + tracer provider. Idempotent; safe
// to call from both server and client mains.
void InitOtel(const std::string& service_name);

}  // namespace otel
