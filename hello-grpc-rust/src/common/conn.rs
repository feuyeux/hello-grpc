#![allow(dead_code)]
#![allow(unused_variables)]

use std::env;
use std::fs;
use std::future::Future;
use std::time::Duration;

use log::{error, info, warn};
use tonic::codec::CompressionEncoding;
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Endpoint, Identity};
use tonic::{Code, Status};

use crate::common::etcd;
use crate::common::landing::landing_service_client::LandingServiceClient;
use crate::common::trans;

const DOMAIN_NAME: &str = "hello.grpc.io";
pub const CONFIG_PATH: &str = "config/log4rs.yml";

/// A6 client-retry parameters for hello.LandingService, mirroring the
/// grpc.service_config retryPolicy used by the other language clients:
/// https://github.com/grpc/proposal/blob/master/A6-client-retries.md
///
/// tonic (0.14.x) has no built-in service-config/retryPolicy support, so
/// this is applied at the application level around unary calls instead of
/// via channel configuration.
pub const RETRY_MAX_ATTEMPTS: u32 = 4;
pub const RETRY_INITIAL_BACKOFF: Duration = Duration::from_millis(100);
pub const RETRY_MAX_BACKOFF: Duration = Duration::from_secs(1);
pub const RETRY_BACKOFF_MULTIPLIER: f64 = 2.0;

/// Returns true when `code` matches the retryableStatusCodes used by the
/// shared A6 retry policy (`UNAVAILABLE` only).
fn is_retryable(code: Code) -> bool {
    code == Code::Unavailable
}

/// Runs `attempt` up to [`RETRY_MAX_ATTEMPTS`] times, retrying only on
/// `UNAVAILABLE` with exponential backoff (initial 0.1s, multiplier 2.0,
/// capped at 1s) — the same policy encoded in the other languages'
/// `retryPolicy` service config for `hello.LandingService`.
pub async fn call_with_retry<T, F, Fut>(method: &str, mut attempt: F) -> Result<T, Status>
where
    F: FnMut() -> Fut,
    Fut: Future<Output = Result<T, Status>>,
{
    let mut backoff = RETRY_INITIAL_BACKOFF;
    let mut last_err = None;
    for attempt_no in 1..=RETRY_MAX_ATTEMPTS {
        match attempt().await {
            Ok(value) => return Ok(value),
            Err(status) => {
                if attempt_no == RETRY_MAX_ATTEMPTS || !is_retryable(status.code()) {
                    last_err = Some(status);
                    break;
                }
                warn!(
                    "{} attempt {}/{} failed with {:?}, retrying in {:?}",
                    method,
                    attempt_no,
                    RETRY_MAX_ATTEMPTS,
                    status.code(),
                    backoff
                );
                tokio::time::sleep(backoff).await;
                backoff = std::cmp::min(
                    Duration::from_secs_f64(backoff.as_secs_f64() * RETRY_BACKOFF_MULTIPLIER),
                    RETRY_MAX_BACKOFF,
                );
                last_err = Some(status);
            }
        }
    }
    Err(last_err.unwrap_or_else(|| Status::unavailable("retry loop exhausted")))
}

/// HTTP/2 keepalive settings shared by secure and insecure channels.
fn with_keepalive(endpoint: Endpoint) -> Endpoint {
    endpoint
        .http2_keep_alive_interval(Duration::from_secs(10))
        .keep_alive_timeout(Duration::from_secs(1))
        .keep_alive_while_idle(true)
}

pub async fn build_client() -> LandingServiceClient<Channel> {
    // Check etcd service discovery first
    if etcd::is_etcd_discovery() {
        match etcd::resolve_from_etcd().await {
            Ok(address) => {
                info!("Resolved service via etcd: {}", address);
                let endpoint = Endpoint::from_shared(address.clone())
                    .unwrap_or_else(|error| panic!("Invalid etcd-resolved address: {:?}", error));
                let channel = with_keepalive(endpoint)
                    .connect()
                    .await
                    .unwrap_or_else(|error| {
                        panic!("Failed to connect to etcd-resolved address: {:?}", error)
                    });
                return LandingServiceClient::new(channel)
                    .send_compressed(CompressionEncoding::Gzip)
                    .accept_compressed(CompressionEncoding::Gzip);
            }
            Err(e) => {
                error!("etcd discovery enabled but resolution failed: {}", e);
                panic!(
                    "GRPC_HELLO_DISCOVERY=etcd but no service instance found: {}",
                    e
                );
            }
        }
    }

    let is_tls = env::var("GRPC_HELLO_SECURE").is_ok_and(|v| v == "Y");

    if is_tls {
        let address = format!("https://{}:{}", grpc_backend_host(), grpc_backend_port());

        // Load certificates at runtime. Resolution order: CERT_BASE_PATH env
        // var, then the platform default. Fail fast when TLS is requested but
        // the certificates cannot be read.
        let cert = fs::read(trans::client_cert_chain()).unwrap_or_else(|e| {
            panic!(
                "GRPC_HELLO_SECURE=Y but failed to read client cert chain {:?}: {}",
                trans::client_cert_chain(),
                e
            )
        });
        let key = fs::read(trans::client_cert_key()).unwrap_or_else(|e| {
            panic!(
                "GRPC_HELLO_SECURE=Y but failed to read client key {:?}: {}",
                trans::client_cert_key(),
                e
            )
        });
        let ca = fs::read(trans::client_root_cert()).unwrap_or_else(|e| {
            panic!(
                "GRPC_HELLO_SECURE=Y but failed to read root cert {:?}: {}",
                trans::client_root_cert(),
                e
            )
        });

        // creating identity from key and certificate
        let identity_cert = Identity::from_pem(cert, key);
        let ca = Certificate::from_pem(ca);

        // telling the client what is the identity of our server
        let tls = ClientTlsConfig::new()
            .domain_name(DOMAIN_NAME)
            .identity(identity_cert)
            .ca_certificate(ca);

        let static_address: &'static str = Box::leak(address.into_boxed_str());
        if let Ok(channel_builder) = Channel::from_static(static_address).tls_config(tls) {
            let channel_builder = with_keepalive(channel_builder);
            if let Ok(channel) = channel_builder.connect().await {
                info!("Connect with TLS(:{})", grpc_backend_port());
                // Enables gzip compression for outgoing/incoming messages.
                return LandingServiceClient::new(channel)
                    .send_compressed(CompressionEncoding::Gzip)
                    .accept_compressed(CompressionEncoding::Gzip);
            } else {
                error!("Failed to connect with TLS");
            }
        } else {
            error!("Failed to build TLS client configuration");
        }
    }

    let address = format!("http://{}:{}", grpc_backend_host(), grpc_backend_port());
    info!(
        "Connect with insecure connection (:{})",
        grpc_backend_port()
    );
    info!("Connect with insecure address: {}", address);
    let endpoint = Endpoint::from_shared(address)
        .unwrap_or_else(|error| panic!("Invalid gRPC server address: {:?}", error));
    let channel = with_keepalive(endpoint)
        .connect()
        .await
        .unwrap_or_else(|error| panic!("Failed to connect to gRPC server: {:?}", error));
    // Enables gzip compression for outgoing/incoming messages.
    LandingServiceClient::new(channel)
        .send_compressed(CompressionEncoding::Gzip)
        .accept_compressed(CompressionEncoding::Gzip)
}

fn grpc_server() -> String {
    // Default to IPv4 "localhost" rather than "[::1]" so that this client
    // interoperates with TS / Java / Go servers, which default to binding
    // `0.0.0.0` / `127.0.0.1`. A pure-IPv6 target here would hit
    // `ConnectionRefused` when the server only listens on IPv4. Override with
    // `GRPC_SERVER=<host>` if you need to point at an explicit address.
    env::var("GRPC_SERVER").unwrap_or_else(|_| "localhost".to_string())
}

pub fn has_backend() -> bool {
    env::var("GRPC_HELLO_BACKEND").is_ok_and(|val| !val.is_empty())
}

#[inline]
pub fn grpc_backend_host() -> String {
    env::var("GRPC_HELLO_BACKEND").unwrap_or_else(|_| grpc_server())
}

#[inline]
fn grpc_backend_port() -> String {
    env::var("GRPC_HELLO_BACKEND_PORT")
        .or_else(|_| env::var("GRPC_SERVER_PORT"))
        .unwrap_or_else(|_| "9996".to_string())
}
