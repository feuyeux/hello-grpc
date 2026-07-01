// hello-grpc-cpp OpenTelemetry wiring.
//
// Mirrors the env-gate pattern used by the Go (#486), Python (#488),
// Node.js/TS (#489), Rust (#490), and C# (#491) implementations:
// GRPC_HELLO_OTEL=Y installs a stdout-exporting OpenTelemetry tracer
// provider. RPC call paths create manual spans through SpanScope because
// grpc-cpp does not expose a stable tracing interceptor API here. When the
// env var is unset the helper is a no-op and the existing paths are preserved.
//
// The full OTLP backend swap is documented inline.

#include "common/otel.h"

#include <cstdlib>
#include <iostream>
#include <memory>
#include <string>

#include "opentelemetry/exporters/ostream/span_exporter_factory.h"
#include "opentelemetry/sdk/common/global_log_handler.h"
#include "opentelemetry/sdk/trace/processor.h"
#include "opentelemetry/sdk/trace/simple_processor_factory.h"
#include "opentelemetry/sdk/trace/tracer_provider_factory.h"
#include "opentelemetry/sdk/trace/tracer_provider.h"
#include "opentelemetry/trace/provider.h"

namespace otel {
namespace {

bool env_enabled() {
  const char* v = std::getenv("GRPC_HELLO_OTEL");
  return v && std::string(v) == "Y";
}

}  // namespace

bool Enabled() { return env_enabled(); }

void InitOtel(const std::string& service_name) {
  if (!env_enabled()) return;

  // OStream exporter (stdout) for the teaching/demo posture. Swap
  // for OtlpHttpExporter / OtlpGrpcExporter here without changing
  // any other call site.
  auto exporter =
      opentelemetry::exporter::trace::OStreamSpanExporterFactory::Create();
  auto processor = opentelemetry::sdk::trace::SimpleSpanProcessorFactory::Create(
      std::move(exporter));
  static auto sdk_provider =
      opentelemetry::sdk::trace::TracerProviderFactory::Create(std::move(processor));
  opentelemetry::trace::Provider::SetTracerProvider(
      opentelemetry::nostd::shared_ptr<opentelemetry::trace::TracerProvider>(
          sdk_provider.release()));

  std::cerr << "[otel] hello-grpc-cpp OpenTelemetry tracing enabled for "
            << service_name << std::endl;
}

SpanScope::SpanScope(const std::string& name) {
  if (!env_enabled()) return;
  auto provider = opentelemetry::trace::Provider::GetTracerProvider();
  auto tracer = provider->GetTracer("hello-grpc-cpp");
  span_ = tracer->StartSpan(name);
}

SpanScope::~SpanScope() {
  if (span_) {
    span_->End();
  }
}

void SpanScope::SetError(const std::string& message) {
  if (span_) {
    span_->SetStatus(opentelemetry::trace::StatusCode::kError, message);
  }
}

}  // namespace otel
