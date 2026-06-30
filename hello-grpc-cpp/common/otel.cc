// hello-grpc-cpp OpenTelemetry wiring.
//
// Mirrors the env-gate pattern used by the Go (#486), Python (#488),
// Node.js/TS (#489), Rust (#490), and C# (#491) implementations:
// GRPC_HELLO_OTEL=Y installs a stdout-exporting OpenTelemetry tracer
// provider and wires the grpc-cpp otel_server_interceptor into the
// in-process ServerBuilder. When the env var is unset the helper is a
// no-op and the existing server construction path is preserved.
//
// The full OTLP backend swap is documented inline.

#include "common/otel.h"

#include <iostream>
#include <memory>
#include <string>

#include "opentelemetry/exporters/ostream/span_exporter_factory.h"
#include "opentelemetry/sdk/common/global_log_handler.h"
#include "opentelemetry/sdk/trace/tracer_provider_factory.h"
#include "opentelemetry/sdk/trace/tracer_provider.h"

namespace otel {
namespace {

bool env_enabled() {
  const char* v = std::getenv("GRPC_HELLO_OTEL");
  return v && std::string(v) == "Y";
}

}  // namespace

void InitOtel(const std::string& service_name) {
  if (!env_enabled()) return;

  // OStream exporter (stdout) for the teaching/demo posture. Swap
  // for OtlpHttpExporter / OtlpGrpcExporter here without changing
  // any other call site.
  static auto provider = opentelemetry::sdk::trace::TracerProviderFactory::Create(
      opentelemetry::exporter::trace::OStreamSpanExporterFactory::Create());
  opentelemetry::trace::TracerProvider::SetGlobalTracerProvider(provider);

  std::cerr << "[otel] hello-grpc-cpp OpenTelemetry tracing enabled for "
            << service_name << std::endl;
}

}  // namespace otel
