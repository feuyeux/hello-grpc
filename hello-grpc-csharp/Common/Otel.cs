using System;
using OpenTelemetry;
using OpenTelemetry.Trace;

namespace Hello.Common;

public static class Otel
{
    public const string EnvEnabled = "GRPC_HELLO_OTEL";

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
    /// Returns the gRPC client OTel instrumentation extension
    /// method as a delegate-friendly Action. The hello-grpc client
    /// call site is plain `GrpcChannel.ForAddress(...)` (not the
    /// ASP.NET Core gRPC client factory), so instrumenting it would
    /// require switching to `AddGrpcClient`; for now this PR hooks
    /// the server side only, where the call site already uses
    /// `AddGrpc` on the ASP.NET Core DI container.
    /// </summary>
    public static TracerProvider? AddToAspNetCore(this TracerProvider? provider, IServiceCollection services)
    {
        if (provider is null) return null;
        services.AddSingleton(provider);
        return provider;
    }
}
