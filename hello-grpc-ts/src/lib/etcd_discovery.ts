/**
 * etcd v3 service discovery via HTTP API (TypeScript).
 *
 * Env vars:
 *   GRPC_HELLO_DISCOVERY=etcd        enable discovery
 *   GRPC_HELLO_DISCOVERY_ENDPOINT    etcd endpoint (default http://127.0.0.1:2379)
 */

import * as http from 'http';

const SVC_DISC_NAME = 'hello-grpc';
const ETCD_KEY = `/etcd/${SVC_DISC_NAME}`;
const DEFAULT_TTL = 5;

function getEndpoint(): string {
    let ep = process.env.GRPC_HELLO_DISCOVERY_ENDPOINT || 'http://127.0.0.1:2379';
    if (!ep.startsWith('http://') && !ep.startsWith('https://')) {
        ep = 'http://' + ep;
    }
    return ep;
}

function post(path: string, payload: any): Promise<any> {
    return new Promise((resolve, reject) => {
        const ep = new URL(getEndpoint());
        const data = JSON.stringify(payload);
        const req = http.request({
            hostname: ep.hostname,
            port: parseInt(ep.port, 10),
            path,
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
            timeout: 5000,
        }, (res) => {
            let body = '';
            res.on('data', (chunk: Buffer) => body += chunk.toString());
            res.on('end', () => {
                try { resolve(JSON.parse(body)); }
                catch (e) { reject(new Error(`etcd response parse error: ${body}`)); }
            });
        });
        req.on('error', reject);
        req.on('timeout', () => { req.destroy(); reject(new Error('etcd request timeout')); });
        req.write(data);
        req.end();
    });
}

function b64(s: string): string {
    return Buffer.from(s, 'utf-8').toString('base64');
}

function b64decode(s: string): string {
    return Buffer.from(s, 'base64').toString('utf-8');
}

export function isEtcdDiscovery(): boolean {
    return process.env.GRPC_HELLO_DISCOVERY === 'etcd';
}

export async function resolveFromEtcd(): Promise<string | null> {
    const resp = await post('/v3/kv/range', { key: b64(ETCD_KEY) });
    const kvs = resp.kvs || [];
    if (kvs.length === 0) return null;
    return b64decode(kvs[0].value);
}

export async function registerToEtcd(host: string, port: string | number): Promise<() => void> {
    const address = `${host}:${port}`;
    // Grant lease
    const leaseResp = await post('/v3/lease/grant', { TTL: DEFAULT_TTL });
    const leaseId = parseInt(leaseResp.ID || '0', 10);
    if (leaseId === 0) throw new Error(`etcd lease grant failed: ${JSON.stringify(leaseResp)}`);
    // Put key with lease
    await post('/v3/kv/put', { key: b64(ETCD_KEY), value: b64(address), lease: leaseId });
    // Start keepalive interval
    const timer = setInterval(async () => {
        try { await post('/v3/lease/keepalive', { ID: leaseId }); }
        catch (e) { /* ignore keepalive errors */ }
    }, (DEFAULT_TTL - 1) * 1000);
    return () => clearInterval(timer);
}

export { SVC_DISC_NAME, ETCD_KEY };
