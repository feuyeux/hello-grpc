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
//
// B2 — Metrics: initOtel also installs a MeterProvider with a
// ConsoleMetricExporter. Use getCounter(name) to obtain a Counter
// instrument; returns null when otel is not enabled.

const envOtelEnabled = "GRPC_HELLO_OTEL";

function otelEnabled() {
  return process.env[envOtelEnabled] === "Y";
}

let initialized = false;
// B2: module-level meter, set in initOtel when the SDK is available.
let _meter = null;

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
  //     @opentelemetry/instrumentation-grpc \
  //     @opentelemetry/sdk-metrics
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

    // B2 — Metrics setup
    const { MeterProvider, PeriodicExportingMetricReader } = require(
      "@opentelemetry/sdk-metrics"
    );
    const { ConsoleMetricExporter } = require("@opentelemetry/sdk-metrics");
    const meterProvider = new MeterProvider({
      readers: [
        new PeriodicExportingMetricReader({
          exporter: new ConsoleMetricExporter(),
          exportIntervalMillis: 30000,
        }),
      ],
    });
    const otelApi = require("@opentelemetry/api");
    otelApi.metrics.setGlobalMeterProvider(meterProvider);
    _meter = otelApi.metrics.getMeter(serviceName);

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
      "@opentelemetry/instrumentation-grpc @opentelemetry/sdk-metrics` to enable GRPC_HELLO_OTEL=Y."
    );
    return;
  }
  nodeSdk.start();
  // Convenience: surface a global for tests / debugging.
  global.__otelSdk = nodeSdk;
}

/**
 * Return a Counter instrument with the given name (B2).
 * Returns null when otel is not enabled or the SDK was not loaded.
 * @param {string} name
 * @param {string} [description]
 * @returns {import("@opentelemetry/api").Counter|null}
 */
function getCounter(name, description) {
  if (_meter === null) return null;
  return _meter.createCounter(name, { description });
}

module.exports = { envOtelEnabled, otelEnabled, initOtel, getCounter };
