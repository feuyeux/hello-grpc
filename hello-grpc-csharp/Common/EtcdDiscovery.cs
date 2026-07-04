using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace Common;

/// <summary>
/// etcd v3 service discovery via HTTP API.
///
/// Uses the etcd v3 gRPC-gateway HTTP endpoint to register and resolve
/// service instances without requiring a native etcd client library.
///
/// Env vars:
///   GRPC_HELLO_DISCOVERY=etcd        enable discovery
///   GRPC_HELLO_DISCOVERY_ENDPOINT    etcd endpoint (default http://127.0.0.1:2379)
/// </summary>
public static class EtcdDiscovery
{
    private const string SvcDiscName = "hello-grpc";
    private const string EtcdKey = "/etcd/hello-grpc";
    private const int DefaultTtl = 5;
    private static readonly HttpClient Client = new() { Timeout = TimeSpan.FromSeconds(5) };

    private static string GetEndpoint()
    {
        var ep = Environment.GetEnvironmentVariable("GRPC_HELLO_DISCOVERY_ENDPOINT")
                 ?? "http://127.0.0.1:2379";
        if (!ep.StartsWith("http://") && !ep.StartsWith("https://"))
            ep = "http://" + ep;
        return ep;
    }

    private static async Task<JsonElement> PostAsync(string path, object payload)
    {
        var url = GetEndpoint() + path;
        var json = JsonSerializer.Serialize(payload);
        var content = new StringContent(json, Encoding.UTF8, "application/json");
        var resp = await Client.PostAsync(url, content);
        resp.EnsureSuccessStatusCode();
        var body = await resp.Content.ReadAsStringAsync();
        return JsonDocument.Parse(body).RootElement;
    }

    private static string B64(string s) => Convert.ToBase64String(Encoding.UTF8.GetBytes(s));
    private static string B64Decode(string s) => Encoding.UTF8.GetString(Convert.FromBase64String(s));

    public static bool IsEtcdDiscovery()
        => Environment.GetEnvironmentVariable("GRPC_HELLO_DISCOVERY") == "etcd";

    public static async Task<string?> ResolveFromEtcdAsync()
    {
        var resp = await PostAsync("/v3/kv/range", new { key = B64(EtcdKey) });
        if (resp.TryGetProperty("kvs", out var kvs) && kvs.GetArrayLength() > 0)
        {
            var val = kvs[0].GetProperty("value").GetString();
            if (val != null) return B64Decode(val);
        }
        return null;
    }

    public static async Task<CancellationTokenSource> RegisterToEtcdAsync(string host, int port)
    {
        var address = $"{host}:{port}";
        // Grant lease
        var leaseResp = await PostAsync("/v3/lease/grant", new { TTL = DefaultTtl });
        var leaseId = leaseResp.GetProperty("ID").GetInt64();
        if (leaseId == 0)
            throw new InvalidOperationException($"etcd lease grant failed: {leaseResp}");
        // Put key with lease
        await PostAsync("/v3/kv/put", new
        {
            key = B64(EtcdKey),
            value = B64(address),
            lease = leaseId.ToString(),
        });
        // Start keepalive timer
        var cts = new CancellationTokenSource();
        _ = Task.Run(async () =>
        {
            while (!cts.Token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(TimeSpan.FromSeconds(DefaultTtl - 1), cts.Token);
                    await PostAsync("/v3/lease/keepalive", new { ID = leaseId.ToString() });
                }
                catch (OperationCanceledException) { break; }
                catch { /* ignore keepalive errors */ }
            }
        }, cts.Token);
        return cts;
    }
}
