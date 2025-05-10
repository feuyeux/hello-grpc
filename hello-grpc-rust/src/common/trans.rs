#![allow(dead_code)]
#![allow(unused_variables)]

pub static TRACING_KEYS: [&'static str; 7] = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context",
];

#[cfg(target_os = "linux")]
pub const CERT: &str = "/var/hello_grpc/server_certs/cert.pem";
#[cfg(target_os = "linux")]
pub const CERT_KEY: &str = "/var/hello_grpc/server_certs/private.key";
#[cfg(target_os = "linux")]
pub const CERT_CHAIN: &str = "/var/hello_grpc/server_certs/full_chain.pem";
#[cfg(target_os = "linux")]
pub const ROOT_CERT: &str = "/var/hello_grpc/server_certs/myssl_root.cer";

#[cfg(target_os = "windows")]
pub const CERT: &str = "d:\\garden\\var\\hello_grpc\\server_certs\\cert.pem";
#[cfg(target_os = "windows")]
pub const CERT_KEY: &str = "d:\\garden\\var\\hello_grpc\\server_certs\\private.key";
#[cfg(target_os = "windows")]
pub const CERT_CHAIN: &str = "d:\\garden\\var\\hello_grpc\\server_certs\\full_chain.pem";
#[cfg(target_os = "windows")]
pub const ROOT_CERT: &str = "d:\\garden\\var\\hello_grpc\\server_certs\\myssl_root.cer";

#[cfg(target_os = "macos")]
pub const CERT: &str = "/var/hello_grpc/server_certs/cert.pem";
#[cfg(target_os = "macos")]
pub const CERT_KEY: &str = "/var/hello_grpc/server_certs/private.key";
#[cfg(target_os = "macos")]
pub const CERT_CHAIN: &str = "/var/hello_grpc/server_certs/full_chain.pem";
#[cfg(target_os = "macos")]
pub const ROOT_CERT: &str = "/var/hello_grpc/server_certs/myssl_root.cer";
