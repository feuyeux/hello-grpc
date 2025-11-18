use log::{info, error};
use std::time::Instant;
use tonic::{Request, metadata::MetadataMap, Status};

const SERVICE_NAME: &str = "rust";

/// Extract request ID from metadata
pub fn extract_request_id(metadata: &MetadataMap) -> String {
    // Try multiple request ID header variants
    if let Some(value) = metadata.get("x-request-id") {
        if let Ok(s) = value.to_str() {
            return s.to_string();
        }
    }
    if let Some(value) = metadata.get("request-id") {
        if let Ok(s) = value.to_str() {
            return s.to_string();
        }
    }
    "unknown".to_string()
}

/// Extract peer address from request
pub fn extract_peer<T>(request: &Request<T>) -> String {
    request
        .remote_addr()
        .map(|addr| addr.to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

/// Check if connection is secure
pub fn is_secure() -> bool {
    std::env::var("GRPC_HELLO_SECURE")
        .map(|v| v == "Y")
        .unwrap_or(false)
}

/// Log request start
pub fn log_request_start(method: &str, request_id: &str, peer: &str) {
    let secure = is_secure();
    info!(
        "service={} request_id={} method={} peer={} secure={} status=STARTED",
        SERVICE_NAME, request_id, method, peer, secure
    );
}

/// Log request end
pub fn log_request_end(
    method: &str,
    request_id: &str,
    peer: &str,
    start_time: Instant,
    status: &str,
) {
    let secure = is_secure();
    let duration_ms = start_time.elapsed().as_millis();
    info!(
        "service={} request_id={} method={} peer={} secure={} duration_ms={} status={}",
        SERVICE_NAME, request_id, method, peer, secure, duration_ms, status
    );
}

/// Log request error
pub fn log_request_error(
    method: &str,
    request_id: &str,
    peer: &str,
    start_time: Instant,
    status: &Status,
) {
    let secure = is_secure();
    let duration_ms = start_time.elapsed().as_millis();
    let error_code = format!("{:?}", status.code());
    let message = status.message();
    
    error!(
        "service={} request_id={} method={} peer={} secure={} duration_ms={} status={} error_code={} message={}",
        SERVICE_NAME, request_id, method, peer, secure, duration_ms, error_code, error_code, message
    );
}
