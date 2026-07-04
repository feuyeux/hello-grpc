//! etcd v3 service discovery via HTTP API.
//!
//! Uses the etcd v3 gRPC-gateway HTTP endpoint to register and resolve
//! service instances without requiring a native etcd client library.
//!
//! Env vars:
//!   GRPC_HELLO_DISCOVERY=etcd        enable discovery
//!   GRPC_HELLO_DISCOVERY_ENDPOINT    etcd endpoint (default http://127.0.0.1:2379)

use base64::Engine;
use log::{info, warn};
use serde_json::json;
use std::env;
use std::time::Duration;
use tokio::sync::oneshot;

const SVC_DISC_NAME: &str = "hello-grpc";
const ETCD_KEY: &str = "/etcd/hello-grpc";
const DEFAULT_TTL: i64 = 5;

fn get_endpoint() -> String {
    let ep = env::var("GRPC_HELLO_DISCOVERY_ENDPOINT")
        .unwrap_or_else(|_| "http://127.0.0.1:2379".to_string());
    if ep.starts_with("http://") || ep.starts_with("https://") {
        ep
    } else {
        format!("http://{}", ep)
    }
}

async fn post(path: &str, payload: serde_json::Value) -> Result<serde_json::Value, Box<dyn std::error::Error>> {
    let url = format!("{}{}", get_endpoint(), path);
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(5))
        .build()?;
    let resp = client
        .post(&url)
        .header("Content-Type", "application/json")
        .json(&payload)
        .send()
        .await?;
    let body: serde_json::Value = resp.json().await?;
    Ok(body)
}

fn b64(s: &str) -> String {
    base64::engine::general_purpose::STANDARD.encode(s.as_bytes())
}

fn b64_decode(s: &str) -> String {
    base64::engine::general_purpose::STANDARD
        .decode(s)
        .map(|b| String::from_utf8_lossy(&b).to_string())
        .unwrap_or_default()
}

pub fn is_etcd_discovery() -> bool {
    env::var("GRPC_HELLO_DISCOVERY").as_deref() == Ok("etcd")
}

pub async fn resolve_from_etcd() -> Result<String, Box<dyn std::error::Error>> {
    let resp = post("/v3/kv/range", json!({ "key": b64(ETCD_KEY) })).await?;
    if let Some(kvs) = resp["kvs"].as_array() {
        if !kvs.is_empty() {
            if let Some(val) = kvs[0]["value"].as_str() {
                return Ok(b64_decode(val));
            }
        }
    }
    Err("no service instance found in etcd".into())
}

pub async fn register_to_etcd(host: &str, port: u16) -> Result<oneshot::Sender<()>, Box<dyn std::error::Error>> {
    let address = format!("{}:{}", host, port);
    // Grant lease
    let lease_resp = post("/v3/lease/grant", json!({ "TTL": DEFAULT_TTL })).await?;
    let lease_id = lease_resp["ID"]
        .as_str()
        .and_then(|s| s.parse::<i64>().ok())
        .or_else(|| lease_resp["ID"].as_i64())
        .unwrap_or(0);
    if lease_id == 0 {
        return Err(format!("etcd lease grant failed: {:?}", lease_resp).into());
    }
    // Put key with lease
    post("/v3/kv/put", json!({
        "key": b64(ETCD_KEY),
        "value": b64(&address),
        "lease": lease_id.to_string(),
    })).await?;
    info!("Registered with etcd: {} (lease={})", address, lease_id);

    // Start keepalive task
    let (tx, mut rx) = oneshot::channel::<()>();
    tokio::spawn(async move {
        loop {
            tokio::select! {
                _ = tokio::time::sleep(Duration::from_secs((DEFAULT_TTL - 1) as u64)) => {
                    if let Err(e) = post("/v3/lease/keepalive", json!({ "ID": lease_id.to_string() })).await {
                        warn!("etcd keepalive error: {}", e);
                    }
                }
                _ = &mut rx => {
                    info!("Stopping etcd keepalive");
                    break;
                }
            }
        }
    });
    Ok(tx)
}
