// hello-grpc-ts OpenTelemetry wiring. Mirrors the Go (#486),
// Python (#488), and Node.js (sibling PR) implementations.
//
// B2 — Metrics: initOtel also installs a MeterProvider backed by
// ConsoleMetricExporter. Call getMeter() after initOtel() to create
// Counter / Histogram instruments; returns null when otel is disabled.

const envOtelEnabled = "GRPC_HELLO_OTEL";

export function otelEnabled(): boolean {
  return process.env[envOtelEnabled] === "Y";
}

let initialized = false;
// B2: module-level meter, set in initOtel when the SDK is available.
let _meter: any = null;

export function initOtel(serviceName: string): void {
  if (!otelEnabled() || initialized) {
    return;
  }
  initialized = true;

  // Lazy require to avoid forcing @opentelemetry/* as a hard
  // dependency. Install via the matching nodejs npm script.
  type NodeSDKType = new (config: any) => { start: () => void };
  type GrpcInstrumentationType = new () => unknown;
  let NodeSDK: NodeSDKType;
  let GrpcInstrumentation: GrpcInstrumentationType;
  let ConsoleSpanExporter: new () => unknown;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const sdkNode = require("@opentelemetry/sdk-node");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const sdkTraceBase = require("@opentelemetry/sdk-trace-base");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const grpcInstrumentation = require("@opentelemetry/instrumentation-grpc");
    NodeSDK = sdkNode.NodeSDK;
    GrpcInstrumentation = grpcInstrumentation.GrpcInstrumentation;
    ConsoleSpanExporter = sdkTraceBase.ConsoleSpanExporter;

    // B2 — Metrics setup
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const sdkMetrics = require("@opentelemetry/sdk-metrics");
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const otelApi = require("@opentelemetry/api");
    const meterProvider = new sdkMetrics.MeterProvider({
      readers: [
        new sdkMetrics.PeriodicExportingMetricReader({
          exporter: new sdkMetrics.ConsoleMetricExporter(),
          exportIntervalMillis: 30000,
        }),
      ],
    });
    otelApi.metrics.setGlobalMeterProvider(meterProvider);
    _meter = otelApi.metrics.getMeter(serviceName);
  } catch (e) {
    console.warn(
      "[otel] OpenTelemetry deps not installed; tracing disabled. " +
        "npm install @opentelemetry/api @opentelemetry/sdk-node " +
        "@opentelemetry/sdk-trace-base @opentelemetry/exporter-trace-otlp-http " +
        "@opentelemetry/instrumentation-grpc @opentelemetry/sdk-metrics to enable GRPC_HELLO_OTEL=Y."
    );
    return;
  }

  const sdk = new NodeSDK({
    serviceName,
    spanExporter: new ConsoleSpanExporter(),
    instrumentations: [new GrpcInstrumentation()],
  });
  sdk.start();
}

/**
 * Return the Meter created in initOtel (B2), or null when otel is
 * not enabled or the SDK was not loaded.
 */
export function getMeter(): any {
  return _meter;
}

/**
 * Return a Counter created from the active Meter (B2), or null when
 * OTel is disabled or the SDK was not loaded.
 */
export function getCounter(name: string, description?: string): any {
  const meter = getMeter();
  if (meter === null) return null;
  return meter.createCounter(name, { description });
}
