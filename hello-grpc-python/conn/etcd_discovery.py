"""
etcd v3 service discovery via HTTP API.

Uses the etcd v3 gRPC-gateway HTTP endpoint (port 2379) to register
and resolve service instances without requiring a native etcd client
library. Mirrors the Go/Java pattern:

  Server: grant lease (TTL=5s) -> put key /etcd/hello-grpc -> keepalive loop
  Client: get key /etcd/hello-grac -> parse address -> connect directly

Env vars:
  GRPC_HELLO_DISCOVERY=etcd          enable discovery
  GRPC_HELLO_DISCOVERY_ENDPOINT      etcd endpoint (default http://127.0.0.1:2379)
"""

import base64
import json
import os
import threading
import time
import urllib.request

SVC_DISC_NAME = "hello-grpc"
ETCD_KEY = f"/etcd/{SVC_DISC_NAME}"
DEFAULT_TTL = 5


def _get_endpoint():
    ep = os.getenv("GRPC_HELLO_DISCOVERY_ENDPOINT", "http://127.0.0.1:2379")
    if not ep.startswith("http://") and not ep.startswith("https://"):
        ep = "http://" + ep
    return ep


def _post(path, payload):
    url = f"{_get_endpoint()}{path}"
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _b64(s):
    return base64.b64encode(s.encode("utf-8")).decode("utf-8")


def _b64_decode(s):
    return base64.b64decode(s).decode("utf-8")


def register_to_etcd(host, port):
    """
    Register the server in etcd with a lease and start a keepalive
    background thread. Returns a stop function; call it on shutdown.
    """
    ttl = DEFAULT_TTL
    address = f"{host}:{port}"

    # Grant lease
    resp = _post("/v3/lease/grant", {"TTL": ttl})
    lease_id = int(resp.get("ID", "0"))
    if lease_id == 0:
        raise RuntimeError(f"etcd lease grant failed: {resp}")

    # Put key with lease
    _post("/v3/kv/put", {
        "key": _b64(ETCD_KEY),
        "value": _b64(address),
        "lease": lease_id,
    })

    # Start keepalive thread
    stop_event = threading.Event()

    def _keepalive():
        while not stop_event.wait(ttl - 1):
            try:
                _post("/v3/lease/keepalive", {"ID": lease_id})
            except Exception:
                pass

    t = threading.Thread(target=_keepalive, daemon=True)
    t.start()

    return stop_event


def resolve_from_etcd():
    """
    Query etcd for the service address. Returns "host:port" string
    or None if no instance is registered.
    """
    resp = _post("/v3/kv/range", {"key": _b64(ETCD_KEY)})
    kvs = resp.get("kvs", [])
    if not kvs:
        return None
    value = _b64_decode(kvs[0]["value"])
    return value


def is_etcd_discovery():
    return os.getenv("GRPC_HELLO_DISCOVERY") == "etcd"
