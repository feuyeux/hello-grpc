#![allow(dead_code)]
#![allow(unused_variables)]

use std::env;
use std::path::PathBuf;

pub static TRACING_KEYS: &[&str] = &[
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context",
];

/// Base directory that contains the `server_certs`/`client_certs` folders.
/// Resolution order: `CERT_BASE_PATH` env var, then the platform default.
fn cert_base_path() -> PathBuf {
    if let Ok(base) = env::var("CERT_BASE_PATH") {
        return PathBuf::from(base);
    }
    if cfg!(target_os = "windows") {
        PathBuf::from("d:\\garden\\var\\hello_grpc")
    } else {
        PathBuf::from("/var/hello_grpc")
    }
}

fn server_cert_dir() -> PathBuf {
    cert_base_path().join("server_certs")
}

fn client_cert_dir() -> PathBuf {
    cert_base_path().join("client_certs")
}

pub fn server_cert() -> PathBuf {
    server_cert_dir().join("cert.pem")
}

pub fn server_cert_key() -> PathBuf {
    server_cert_dir().join("private.key")
}

pub fn server_cert_chain() -> PathBuf {
    server_cert_dir().join("full_chain.pem")
}

pub fn server_root_cert() -> PathBuf {
    server_cert_dir().join("myssl_root.cer")
}

pub fn client_cert_chain() -> PathBuf {
    client_cert_dir().join("full_chain.pem")
}

pub fn client_cert_key() -> PathBuf {
    client_cert_dir().join("private.key")
}

pub fn client_root_cert() -> PathBuf {
    client_cert_dir().join("myssl_root.cer")
}
