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

//https://myssl.com/create_test_cert.html
pub const CERT: &str = "/var/hello_grpc/server_certs/cert.pem";
pub const CERT_KEY: &str = "/var/hello_grpc/server_certs/private.key";
pub const CERT_CHAIN: &str = "/var/hello_grpc/server_certs/full_chain.pem";
pub const ROOT_CERT: &str = "/var/hello_grpc/server_certs/myssl_root.cer";