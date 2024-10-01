#![allow(dead_code)]
#![allow(unused_variables)]

use std::env;

use log::{error, info};
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};

use crate::common::landing::landing_service_client::LandingServiceClient;

const DOMAIN_NAME: &str = "hello.grpc.io";
pub const CONFIG_PATH: &str = "config/log4rs.yml";

pub async fn build_client() -> LandingServiceClient<Channel> {
    let is_tls = env::var("GRPC_HELLO_SECURE").unwrap_or_else(|_e| String::default());

    if is_tls.eq("Y") {
        let address = format!("https://{}:{}", grpc_backend_host(), grpc_backend_port());
        //https://myssl.com/create_test_cert.html
        #[cfg(target_os = "windows")]
        let cert = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\full_chain.pem");
        #[cfg(target_os = "windows")]
        let key = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\private.key");
        #[cfg(target_os = "windows")]
        let ca = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\full_chain.pem");

        #[cfg(target_os = "linux")]
        let cert = include_str!("/var/hello_grpc/client_certs/full_chain.pem");
        #[cfg(target_os = "linux")]
        let key = include_str!("/var/hello_grpc/client_certs/private.key");
        #[cfg(target_os = "linux")]
        let ca = include_str!("/var/hello_grpc/client_certs/full_chain.pem");

        #[cfg(target_os = "macos")]
        let cert = include_str!("/usr/local/hello_grpc/client_certs/full_chain.pem");
        #[cfg(target_os = "macos")]
        let key = include_str!("/usr/local/hello_grpc/client_certs/private.key");
        #[cfg(target_os = "macos")]
        let ca = include_str!("/usr/local/hello_grpc/client_certs/full_chain.pem");

        // creating identify from key and certificate
        let id = Identity::from_pem(cert.as_bytes(), key.as_bytes());
        let ca = Certificate::from_pem(ca.as_bytes());
        // telling our client what is the identity of our server
        let tls = ClientTlsConfig::new()
            .domain_name(DOMAIN_NAME)
            .identity(id)
            .ca_certificate(ca);
        let s: &'static str = Box::leak(address.into_boxed_str());
        let result = Channel::from_static(s).tls_config(tls);
        match result.unwrap().connect().await {
            Ok(channel) => {
                info!("Connect With TLS(:{})", grpc_backend_port());
                return LandingServiceClient::new(channel);
            }
            Err(error) => {
                error!("Fail to build TLS Client {:?}", error)
            }
        }
    }
    let address = format!("http://{}:{}", grpc_backend_host(), grpc_backend_port());
    info!("Connect With InSecure(:{})", grpc_backend_port());
    info!("Connect With InSecure(:{})", address);
    LandingServiceClient::connect(address).await.unwrap_or_else(|error| {
        panic!("Problem opening the file: {:?}", error)
    })
}

fn grpc_server() -> String {
    env::var("GRPC_SERVER").unwrap_or_else(|_e| "[::1]".to_string())
}

pub fn has_backend() -> bool {
    match env::var("GRPC_HELLO_BACKEND") {
        Ok(val) => val.is_empty(),
        Err(_e) => false,
    }
}

pub fn grpc_backend_host() -> String {
    env::var("GRPC_HELLO_BACKEND").unwrap_or_else(|_e| grpc_server())
}

fn grpc_backend_port() -> String {
    env::var("GRPC_HELLO_BACKEND_PORT").unwrap_or_else(|_e| match env::var("GRPC_SERVER_PORT") {
        Ok(val) => val,
        Err(_e) => "9996".to_string(),
    })
}
