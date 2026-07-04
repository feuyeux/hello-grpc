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

const http = require('http');

const SVC_DISC_NAME = 'hello-grpc';
const ETCD_KEY = `/etcd/${SVC_DISC_NAME}`;
const DEFAULT_TTL = 5;

function getEndpoint() {
    let ep = process.env.GRPC_HELLO_DISCOVERY_ENDPOINT || 'http://127.0.0.1:2379';
    if (!ep.startsWith('http://') && !ep.startsWith('https://')) {
        ep = 'http://' + ep;
    }
    return ep;
}

function post(path, payload) {
    return new Promise((resolve, reject) => {
        const ep = new URL(getEndpoint());
        const data = JSON.stringify(payload);
        const req = http.request({
            hostname: ep.hostname,
            port: ep.port,
            path: path,
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) },
            timeout: 5000,
        }, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
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

function b64(s) { return Buffer.from(s, 'utf-8').toString('base64'); }
function b64decode(s) { return Buffer.from(s, 'base64').toString('utf-8'); }

function isEtcdDiscovery() {
    return process.env.GRPC_HELLO_DISCOVERY === 'etcd';
}

async function resolveFromEtcd() {
    const resp = await post('/v3/kv/range', { key: b64(ETCD_KEY) });
    const kvs = resp.kvs || [];
    if (kvs.length === 0) return null;
    return b64decode(kvs[0].value);
}

async function registerToEtcd(host, port) {
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

module.exports = { isEtcdDiscovery, resolveFromEtcd, registerToEtcd, SVC_DISC_NAME, ETCD_KEY };
