// hello-grpc-cpp OpenTelemetry wiring.
//
// Mirrors the env-gate pattern used by the other implementations:
// GRPC_HELLO_OTEL=Y installs stdout-exporting OpenTelemetry tracer and
// meter providers. When the env var is unset this helper is a no-op and
// the existing server/client construction paths are preserved.

#include "common/otel.h"

#include <cstdlib>
#include <iostream>
#include <memory>
#include <mutex>
#include <string>

#include "opentelemetry/exporters/ostream/metric_exporter_factory.h"
#include "opentelemetry/exporters/ostream/span_exporter_factory.h"
#include "opentelemetry/metrics/meter.h"
#include "opentelemetry/metrics/provider.h"
#include "opentelemetry/metrics/sync_instruments.h"
#include "opentelemetry/sdk/metrics/export/periodic_exporting_metric_reader_factory.h"
#include "opentelemetry/sdk/metrics/meter_provider.h"
#include "opentelemetry/sdk/metrics/meter_provider_factory.h"
#include "opentelemetry/sdk/metrics/push_metric_exporter.h"
#include "opentelemetry/sdk/resource/resource.h"
#include "opentelemetry/sdk/trace/exporter.h"
#include "opentelemetry/sdk/trace/processor.h"
#include "opentelemetry/sdk/trace/simple_processor_factory.h"
#include "opentelemetry/sdk/trace/tracer_provider_factory.h"
#include "opentelemetry/trace/provider.h"

namespace otel {
namespace {

namespace common = opentelemetry::common;
namespace metrics_api = opentelemetry::metrics;
namespace metrics_exporter = opentelemetry::exporter::metrics;
namespace metrics_sdk = opentelemetry::sdk::metrics;
namespace resource = opentelemetry::sdk::resource;
namespace trace_api = opentelemetry::trace;
namespace trace_exporter = opentelemetry::exporter::trace;
namespace trace_sdk = opentelemetry::sdk::trace;

bool env_enabled() {
  const char* v = std::getenv("GRPC_HELLO_OTEL");
  return v && std::string(v) == "Y";
}

std::once_flag init_once;
opentelemetry::nostd::shared_ptr<metrics_api::Counter<uint64_t>>
    rpc_calls_counter;

resource::Resource MakeResource(const std::string& service_name) {
  return resource::Resource::Create(
      {{"service.name", common::AttributeValue(service_name)}});
}

void InitTracerProvider(const std::string& service_name) {
  auto exporter = trace_exporter::OStreamSpanExporterFactory::Create();
  auto processor = trace_sdk::SimpleSpanProcessorFactory::Create(
      std::move(exporter));
  std::shared_ptr<trace_api::TracerProvider> provider =
      trace_sdk::TracerProviderFactory::Create(std::move(processor),
                                               MakeResource(service_name));
  trace_api::Provider::SetTracerProvider(provider);
}

void InitMeterProvider(const std::string& service_name) {
  auto exporter = metrics_exporter::OStreamMetricExporterFactory::Create();

  metrics_sdk::PeriodicExportingMetricReaderOptions options;
  options.export_interval_millis = std::chrono::milliseconds(1000);
  options.export_timeout_millis = std::chrono::milliseconds(500);

  auto reader =
      metrics_sdk::PeriodicExportingMetricReaderFactory::Create(
          std::move(exporter), options);
  auto provider = metrics_sdk::MeterProviderFactory::Create();
  auto* sdk_provider =
      static_cast<metrics_sdk::MeterProvider*>(provider.get());
  sdk_provider->AddMetricReader(std::move(reader));

  std::shared_ptr<metrics_api::MeterProvider> meter_provider(
      std::move(provider));
  metrics_api::Provider::SetMeterProvider(meter_provider);

  auto meter =
      metrics_api::Provider::GetMeterProvider()->GetMeter(service_name);
  rpc_calls_counter = meter->CreateUInt64Counter(
      "rpc_calls_total", "Total number of RPC calls handled", "1");
}

}  // namespace

void InitOtel(const std::string& service_name) {
  if (!env_enabled()) return;

  std::call_once(init_once, [&service_name]() {
    InitTracerProvider(service_name);
    InitMeterProvider(service_name);
    std::cerr << "[otel] OpenTelemetry stdout exporters enabled service.name="
              << service_name << std::endl;
  });
}

void RecordRpcCall(const std::string& method_name,
                   const std::string& service_name) {
  if (!env_enabled()) return;
  if (!rpc_calls_counter) {
    InitOtel(service_name);
  }
  rpc_calls_counter->Add(
      1, {{"rpc.system", common::AttributeValue("grpc")},
          {"rpc.service", common::AttributeValue(service_name)},
          {"rpc.method", common::AttributeValue(method_name)}});
}

void EmitRpcSpan(const std::string& method_name,
                 const std::string& service_name) {
  if (!env_enabled()) return;
  InitOtel(service_name);

  auto tracer =
      trace_api::Provider::GetTracerProvider()->GetTracer("hello-grpc-cpp");
  auto span = tracer->StartSpan(
      service_name + "/" + method_name,
      {{"rpc.system", common::AttributeValue("grpc")},
       {"rpc.service", common::AttributeValue(service_name)},
       {"rpc.method", common::AttributeValue(method_name)}});
  span->End();
}

}  // namespace otel
