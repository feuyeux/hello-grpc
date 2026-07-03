#![allow(dead_code)]
#![allow(unused_variables)]

use std::env;
use std::fs;

use log::{error, info};
use tonic::transport::{Certificate, Channel, ClientTlsConfig, Identity};

use crate::common::landing::landing_service_client::LandingServiceClient;
use crate::common::trans;

const DOMAIN_NAME: &str = "hello.grpc.io";
pub const CONFIG_PATH: &str = "config/log4rs.yml";

pub async fn build_client() -> LandingServiceClient<Channel> {
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
            if let Ok(channel) = channel_builder.connect().await {
                info!("Connect with TLS(:{})", grpc_backend_port());
                return LandingServiceClient::new(channel);
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
    LandingServiceClient::connect(address)
        .await
        .unwrap_or_else(|error| panic!("Failed to connect to gRPC server: {:?}", error))
}

fn grpc_server() -> String {
    env::var("GRPC_SERVER").unwrap_or_else(|_| "[::1]".to_string())
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
