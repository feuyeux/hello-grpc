#![allow(dead_code)]
#![allow(unused_variables)]

use std::env;

use log::{error, info};
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};

use crate::common::landing::landing_service_client::LandingServiceClient;

const DOMAIN_NAME: &str = "hello.grpc.io";
pub const CONFIG_PATH: &str = "config/log4rs.yml";

pub async fn build_client() -> LandingServiceClient<Channel> {
    let is_tls = env::var("GRPC_HELLO_SECURE").unwrap_or_else(|_err| String::default());

    if is_tls.eq("Y") {
        let address = format!("https://{}:{}", grpc_backend_host(), grpc_backend_port());
        // https://myssl.com/create_test_cert.html
        #[cfg(target_os = "windows")]
        let cert = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\full_chain.pem");
        #[cfg(target_os = "windows")]
        let key = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\private.key");
        #[cfg(target_os = "windows")]
        let ca = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\myssl_root.cer");

        #[cfg(target_os = "linux")]
        let cert = include_str!("/var/hello_grpc/client_certs/full_chain.pem");
        #[cfg(target_os = "linux")]
        let key = include_str!("/var/hello_grpc/client_certs/private.key");
        #[cfg(target_os = "linux")]
        let ca = include_str!("/var/hello_grpc/client_certs/myssl_root.cer");

        #[cfg(target_os = "macos")]
        let cert = include_str!("/var/hello_grpc/client_certs/full_chain.pem");
        #[cfg(target_os = "macos")]
        let key = include_str!("/var/hello_grpc/client_certs/private.key");
        #[cfg(target_os = "macos")]
        let ca = include_str!("/var/hello_grpc/client_certs/myssl_root.cer");

        // creating identity from key and certificate
        let identity_cert = Identity::from_pem(cert.as_bytes(), key.as_bytes());
        let ca = Certificate::from_pem(ca.as_bytes());
        // telling the client what is the identity of our server
        let tls = ClientTlsConfig::new()
            .domain_name(DOMAIN_NAME)
            .identity(identity_cert)
            .ca_certificate(ca);
        let static_address: &'static str = Box::leak(address.into_boxed_str());
        let channel_builder = Channel::from_static(static_address).tls_config(tls);
        match channel_builder.unwrap().connect().await {
            Ok(channel) => {
                info!("Connect with TLS(:{})", grpc_backend_port());
                return LandingServiceClient::new(channel);
            }
            Err(error) => {
                error!("Failed to build TLS client: {:?}", error)
            }
        }
    }
    let address = format!("http://{}:{}", grpc_backend_host(), grpc_backend_port());
    info!("Connect with insecure connection (:{})", grpc_backend_port());
    info!("Connect with insecure address: {}", address);
    LandingServiceClient::connect(address)
        .await
        .unwrap_or_else(|error| panic!("Problem opening the file: {:?}", error))
}

fn grpc_server() -> String {
    env::var("GRPC_SERVER").unwrap_or_else(|_err| "[::1]".to_string())
}

pub fn has_backend() -> bool {
    match env::var("GRPC_HELLO_BACKEND") {
        Ok(val) => val.is_empty(),
        Err(_err) => false,
    }
}

pub fn grpc_backend_host() -> String {
    env::var("GRPC_HELLO_BACKEND").unwrap_or_else(|_err| grpc_server())
}

fn grpc_backend_port() -> String {
    env::var("GRPC_HELLO_BACKEND_PORT")
        .unwrap_or_else(|_err| env::var("GRPC_SERVER_PORT").unwrap_or_else(|_err| "9996".to_string()))
}
