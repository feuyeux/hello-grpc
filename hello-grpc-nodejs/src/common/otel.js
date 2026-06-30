// hello-grpc-nodejs OpenTelemetry wiring.
//
// Mirrors the Go (PR #486) and Python (PR #488) implementations:
// an opt-in env var (GRPC_HELLO_OTEL=Y) installs a global SDK
// and registers the @opentelemetry/instrumentation-grpc patcher
// against @grpc/grpc-js; otherwise the module stays a thin
// no-op so the call sites in src/server/index.js and
// src/client/index.js stay byte-identical to before this commit.
//
// The exporter is stdout for the teaching/demo posture of
// hello-grpc; operators wanting an OTLP backend swap
// ConsoleSpanExporter for OTLPTraceExporter in initOtel.

const envOtelEnabled = "GRPC_HELLO_OTEL";

function otelEnabled() {
  return process.env[envOtelEnabled] === "Y";
}

let initialized = false;

function initOtel(serviceName) {
  if (!otelEnabled() || initialized) {
    return;
  }
  initialized = true;

  // Load lazily so environments without @opentelemetry packages
  // installed (the default repo state) keep importing this module
  // without errors. Install via:
  //   npm install @opentelemetry/api @opentelemetry/sdk-trace-node \
  //     @opentelemetry/exporter-trace-otlp-http \
  //     @opentelemetry/instrumentation-grpc
  let nodeSdk;
  let otel;
  let grpcInstrumentation;
  try {
    const { NodeSDK } = require("@opentelemetry/sdk-node");
    const { ConsoleSpanExporter } = require(
      "@opentelemetry/sdk-trace-base"
    );
    ({ otel } = require("@opentelemetry/api"));
    ({ GrpcInstrumentation } = require(
      "@opentelemetry/instrumentation-grpc"
    ));
    nodeSdk = new NodeSDK({
      serviceName,
      spanExporter: new ConsoleSpanExporter(),
      instrumentations: [new GrpcInstrumentation()],
    });
  } catch (e) {
    // Missing dep path: log once and skip. We deliberately swallow
    // this so that npm install of the OTel packages is opt-in,
    // matching the GRPC_HELLO_OTEL=Y gate.
    console.warn(
      "[otel] OpenTelemetry deps not installed; tracing disabled. " +
      "Run `npm install @opentelemetry/api @opentelemetry/sdk-node " +
      "@opentelemetry/sdk-trace-base @opentelemetry/exporter-trace-otlp-http " +
      "@opentelemetry/instrumentation-grpc` to enable GRPC_HELLO_OTEL=Y."
    );
    return;
  }
  nodeSdk.start();
  // Convenience: surface a global for tests / debugging.
  global.__otelSdk = nodeSdk;
}

module.exports = { envOtelEnabled, otelEnabled, initOtel };
