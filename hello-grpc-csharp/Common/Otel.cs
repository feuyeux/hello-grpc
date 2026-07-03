using System;
using System.Diagnostics;
using System.Diagnostics.Metrics;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace Common;

public static class Otel
{
    public const string EnvEnabled = "GRPC_HELLO_OTEL";
    public const string MeterName = "hello-grpc-csharp";
    public const string ActivitySourceName = "hello-grpc-csharp";
    public static readonly ActivitySource ActivitySource = new(ActivitySourceName);

    public static bool Enabled() => Environment.GetEnvironmentVariable(EnvEnabled) == "Y";

    /// <summary>
    /// Returns a TracerProvider SDK configured with the stdout
    /// exporter. When GRPC_HELLO_OTEL is not "Y", returns null so
    /// the caller can skip registering anything. The provider is
    /// owned by OpenTelemetry.Sdk; callers don't need to dispose it.
    /// </summary>
    public static TracerProvider? InitOtel(string serviceName)
    {
        if (!Enabled()) return null;
        return Sdk.CreateTracerProviderBuilder()
            .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService(serviceName))
            .AddConsoleExporter()
            .Build();
    }

    /// <summary>
    /// Returns a MeterProvider SDK configured with the console exporter.
    /// When GRPC_HELLO_OTEL is not "Y", returns null. The MeterProvider
    /// listens to the hello-grpc-csharp meter so the rpc_calls_total
    /// counter is exported.
    /// </summary>
    public static MeterProvider? InitMetrics(string serviceName)
    {
        if (!Enabled()) return null;
        return Sdk.CreateMeterProviderBuilder()
            .SetResourceBuilder(ResourceBuilder.CreateDefault().AddService(serviceName))
            .AddMeter(MeterName)
            .AddConsoleExporter()
            .Build();
    }

    /// <summary>
    /// Returns an rpc_calls_total counter from the named Meter.
    /// Callers increment it once per incoming RPC.
    /// </summary>
    public static Counter<long> RpcCallsCounter()
    {
        var meter = new Meter(MeterName);
        return meter.CreateCounter<long>("rpc_calls_total", "{call}", "Total number of gRPC calls handled");
    }

    /// <summary>
    /// Starts a server-side RPC Activity with gRPC semantic attributes.
    /// Returns null when OTel is disabled.
    /// </summary>
    public static Activity? StartRpcSpan(string methodName)
    {
        if (!Enabled()) return null;
        var activity = ActivitySource.StartActivity(methodName, ActivityKind.Server);
        activity?.SetTag("rpc.system", "grpc");
        activity?.SetTag("rpc.service", "LandingService");
        activity?.SetTag("rpc.method", methodName);
        return activity;
    }
}
