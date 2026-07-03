// hello-grpc-cpp OpenTelemetry wiring.
//
// Mirrors the env-gate pattern used by the other implementations:
// GRPC_HELLO_OTEL=Y is meant to install stdout-exporting OpenTelemetry
// tracer and meter providers. When the env var is unset this helper is
// a no-op and the existing server/client construction paths are
// preserved.
//
// This is currently a no-op stub: native opentelemetry-cpp is disabled
// in the Bazel build graph (see common/BUILD.bazel and MODULE.bazel).
// Every BCR release of opentelemetry-cpp available for this project's
// pinned grpc/protobuf graph ships a `sdk/src/resource`/`sdk/src/metrics`
// BUILD file whose `glob(["**/*.h"])` matches nothing on the resolved
// source layout, so any target depending on `@io_opentelemetry_cpp`
// fails analysis before a single line of C++ is compiled. Honor the env
// var by logging that the SDK is unavailable instead of installing real
// exporters, so server/client sources compile unchanged and behavior
// stays byte-identical when GRPC_HELLO_OTEL is unset (the default).

#include "common/otel.h"

#include <cstdlib>
#include <iostream>
#include <mutex>
#include <string>

namespace otel {
namespace {

bool env_enabled() {
  const char* v = std::getenv("GRPC_HELLO_OTEL");
  return v && std::string(v) == "Y";
}

std::once_flag warn_once;

void WarnUnavailable(const std::string& service_name) {
  std::call_once(warn_once, [&service_name]() {
    std::cerr << "[otel] GRPC_HELLO_OTEL=Y but the OpenTelemetry C++ SDK is "
                 "unavailable in this build (native opentelemetry-cpp is "
                 "disabled in the Bazel graph); continuing without tracing. "
                 "service.name="
              << service_name << std::endl;
  });
}

}  // namespace

void InitOtel(const std::string& service_name) {
  if (!env_enabled()) return;
  WarnUnavailable(service_name);
}

void RecordRpcCall(const std::string& method_name,
                   const std::string& service_name) {
  if (!env_enabled()) return;
  WarnUnavailable(service_name);
  (void)method_name;
}

void EmitRpcSpan(const std::string& method_name,
                 const std::string& service_name) {
  if (!env_enabled()) return;
  WarnUnavailable(service_name);
  (void)method_name;
}

}  // namespace otel
