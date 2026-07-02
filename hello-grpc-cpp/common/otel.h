// hello-grpc-cpp OpenTelemetry wiring.
//
// Mirrors the env-gate pattern used by the Go (#486), Python (#488),
// Node.js/TS (#489), Rust (#490), and C# (#491) implementations:
// GRPC_HELLO_OTEL=Y installs stdout-exporting OpenTelemetry tracer and
// meter providers. When the env var is unset the helper is a no-op and
// the existing server/client construction paths are preserved.

#pragma once

#include <string>

namespace otel {

// Install the OpenTelemetry SDK + tracer provider. Idempotent; safe
// to call from both server and client mains.
void InitOtel(const std::string& service_name);

// Increment the env-gated rpc_calls_total counter.
void RecordRpcCall(const std::string& method_name,
                   const std::string& service_name = "LandingService");

// Create and end an env-gated RPC span with rpc.system/rpc.method attributes.
void EmitRpcSpan(const std::string& method_name,
                 const std::string& service_name = "LandingService");

}  // namespace otel
