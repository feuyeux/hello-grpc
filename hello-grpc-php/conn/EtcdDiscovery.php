<?php
/**
 * etcd v3 service discovery via HTTP API.
 *
 * Uses the etcd v3 gRPC-gateway HTTP endpoint to register and resolve
 * service instances without requiring a native etcd client library.
 *
 * Env vars:
 *   GRPC_HELLO_DISCOVERY=etcd        enable discovery
 *   GRPC_HELLO_DISCOVERY_ENDPOINT    etcd endpoint (default http://127.0.0.1:2379)
 */

class EtcdDiscovery
{
    const SVC_DISC_NAME = 'hello-grpc';
    const ETCD_KEY = '/etcd/hello-grpc';
    const DEFAULT_TTL = 5;

    private static function getEndpoint(): string
    {
        $ep = getenv('GRPC_HELLO_DISCOVERY_ENDPOINT') ?: 'http://127.0.0.1:2379';
        if (!str_starts_with($ep, 'http://') && !str_starts_with($ep, 'https://')) {
            $ep = 'http://' . $ep;
        }
        return $ep;
    }

    private static function post(string $path, array $payload): array
    {
        $url = self::getEndpoint() . $path;
        $data = json_encode($payload);
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $data);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        $resp = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($resp === false || $code >= 400) {
            throw new RuntimeException("etcd request failed: $path (HTTP $code)");
        }
        return json_decode($resp, true) ?? [];
    }

    private static function b64(string $s): string
    {
        return base64_encode($s);
    }

    private static function b64Decode(string $s): string
    {
        return base64_decode($s);
    }

    public static function isEtcdDiscovery(): bool
    {
        return getenv('GRPC_HELLO_DISCOVERY') === 'etcd';
    }

    public static function resolveFromEtcd(): ?string
    {
        $resp = self::post('/v3/kv/range', ['key' => self::b64(self::ETCD_KEY)]);
        $kvs = $resp['kvs'] ?? [];
        if (empty($kvs)) return null;
        return self::b64Decode($kvs[0]['value']);
    }

    public static function registerToEtcd(string $host, int $port): Closure
    {
        $address = "{$host}:{$port}";
        // Grant lease
        $leaseResp = self::post('/v3/lease/grant', ['TTL' => self::DEFAULT_TTL]);
        $leaseId = (string)($leaseResp['ID'] ?? '0');
        if ($leaseId === '0') {
            throw new RuntimeException('etcd lease grant failed: ' . json_encode($leaseResp));
        }
        // Put key with lease
        self::post('/v3/kv/put', [
            'key' => self::b64(self::ETCD_KEY),
            'value' => self::b64($address),
            'lease' => $leaseId,
        ]);
        // Start keepalive (non-blocking fork)
        $pid = pcntl_fork();
        if ($pid === 0) {
            // Child process: keepalive loop
            while (true) {
                sleep(self::DEFAULT_TTL - 1);
                try {
                    self::post('/v3/lease/keepalive', ['ID' => $leaseId]);
                } catch (Exception $e) {
                    // ignore
                }
            }
        }
        return function () use ($pid) {
            if ($pid > 0) {
                posix_kill($pid, SIGTERM);
            }
        };
    }
}
