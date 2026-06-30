// hello-grpc-ts OpenTelemetry wiring. Mirrors the Go (#486),
// Python (#488), and Node.js (sibling PR) implementations.

const envOtelEnabled = "GRPC_HELLO_OTEL";

export function otelEnabled(): boolean {
  return process.env[envOtelEnabled] === "Y";
}

let initialized = false;

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
  } catch (e) {
    console.warn(
      "[otel] OpenTelemetry deps not installed; tracing disabled. " +
        "npm install @opentelemetry/api @opentelemetry/sdk-node " +
        "@opentelemetry/sdk-trace-base @opentelemetry/exporter-trace-otlp-http " +
        "@opentelemetry/instrumentation-grpc to enable GRPC_HELLO_OTEL=Y."
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
