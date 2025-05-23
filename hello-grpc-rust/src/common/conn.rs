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
        let ca = include_str!("d:\\garden\\var\\hello_grpc\\client_certs\\full_chain.pem");

        #[cfg(target_os = "linux")]
        let cert = include_str!("/var/hello_grpc/client_certs/full_chain.pem");
        #[cfg(target_os = "linux")]
        let key = include_str!("/var/hello_grpc/client_certs/private.key");
        #[cfg(target_os = "linux")]
        let ca = include_str!("/var/hello_grpc/client_certs/full_chain.pem");

        #[cfg(target_os = "macos")]
        let cert = include_str!("/var/hello_grpc/client_certs/full_chain.pem");
        #[cfg(target_os = "macos")]
        let key = include_str!("/var/hello_grpc/client_certs/private.key");
        #[cfg(target_os = "macos")]
        let ca = include_str!("/var/hello_grpc/client_certs/full_chain.pem");

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

pub fn grpc_server() -> String {
    env::var("GRPC_SERVER").unwrap_or_else(|_err| "[::1]".to_string())
}

pub fn has_backend() -> bool {
    match env::var("GRPC_HELLO_BACKEND") {
        Ok(val) => !val.is_empty(),
        Err(_err) => false,
    }
}

pub fn grpc_backend_host() -> String {
    env::var("GRPC_HELLO_BACKEND").unwrap_or_else(|_err| grpc_server())
}

pub fn grpc_backend_port() -> String {
    env::var("GRPC_HELLO_BACKEND_PORT")
        .unwrap_or_else(|_err| env::var("GRPC_SERVER_PORT").unwrap_or_else(|_err| "9996".to_string()))
}

#[cfg(test)]
mod tests {
    use super::*; // Imports items from the outer module (conn)
    use std::env;

    // Helper to temporarily set an environment variable
    fn with_env_var<F>(key: &str, value: Option<&str>, mut closure: F)
    where
        F: FnMut(),
    {
        let original_value = env::var(key).ok();
        if let Some(v) = value {
            env::set_var(key, v);
        } else {
            env::remove_var(key);
        }

        closure();

        // Restore original value
        if let Some(orig_v) = original_value {
            env::set_var(key, orig_v);
        } else {
            env::remove_var(key);
        }
    }
    
    // Helper for multiple env vars
    fn with_env_vars<F>(vars: Vec<(&str, Option<&str>)>, mut closure: F)
    where
        F: FnMut(),
    {
        let original_values: Vec<(&str, Option<String>)> = vars
            .iter()
            .map(|(k, _)| (*k, env::var(*k).ok()))
            .collect();

        for (k, v_opt) in vars {
            if let Some(v) = v_opt {
                env::set_var(k, v);
            } else {
                env::remove_var(k);
            }
        }

        closure();

        // Restore original values
        for (k, orig_v_opt) in original_values {
            if let Some(orig_v) = orig_v_opt {
                env::set_var(k, orig_v);
            } else {
                env::remove_var(k);
            }
        }
    }


    #[test]
    fn test_grpc_server_default() {
        with_env_var("GRPC_SERVER", None, || {
            assert_eq!(grpc_server(), "[::1]");
        });
    }

    #[test]
    fn test_grpc_server_custom() {
        with_env_var("GRPC_SERVER", Some("myhost.com"), || {
            assert_eq!(grpc_server(), "myhost.com");
        });
    }

    #[test]
    fn test_has_backend_false_by_default() {
        with_env_var("GRPC_HELLO_BACKEND", None, || {
            assert_eq!(has_backend(), false);
        });
    }

    #[test]
    fn test_has_backend_false_if_empty() {
        with_env_var("GRPC_HELLO_BACKEND", Some(""), || {
            assert_eq!(has_backend(), false); // Corrected logic: !val.is_empty()
        });
    }

    #[test]
    fn test_has_backend_true_if_set() {
        with_env_var("GRPC_HELLO_BACKEND", Some("backendhost"), || {
            assert_eq!(has_backend(), true); // Corrected logic: !val.is_empty()
        });
    }

    #[test]
    fn test_grpc_backend_host_uses_backend_var() {
        with_env_vars(vec![
            ("GRPC_HELLO_BACKEND", Some("backend.example.com")),
            ("GRPC_SERVER", Some("server.example.com")) // Should be ignored
        ], || {
            assert_eq!(grpc_backend_host(), "backend.example.com");
        });
    }

    #[test]
    fn test_grpc_backend_host_uses_server_var_if_backend_not_set() {
         with_env_vars(vec![
            ("GRPC_HELLO_BACKEND", None),
            ("GRPC_SERVER", Some("server.example.com"))
        ], || {
            assert_eq!(grpc_backend_host(), "server.example.com");
        });
    }
    
    #[test]
    fn test_grpc_backend_host_default_if_neither_set() {
        with_env_vars(vec![
            ("GRPC_HELLO_BACKEND", None),
            ("GRPC_SERVER", None)
        ], || {
            assert_eq!(grpc_backend_host(), "[::1]");
        });
    }

    #[test]
    fn test_grpc_backend_port_default() {
        with_env_vars(vec![
            ("GRPC_HELLO_BACKEND_PORT", None),
            ("GRPC_SERVER_PORT", None)
        ], || {
            assert_eq!(grpc_backend_port(), "9996");
        });
    }

    #[test]
    fn test_grpc_backend_port_uses_server_port_var() {
         with_env_vars(vec![
            ("GRPC_HELLO_BACKEND_PORT", None),
            ("GRPC_SERVER_PORT", Some("12345"))
        ], || {
            assert_eq!(grpc_backend_port(), "12345");
        });
    }

    #[test]
    fn test_grpc_backend_port_uses_backend_port_var() {
        with_env_vars(vec![
            ("GRPC_HELLO_BACKEND_PORT", Some("54321")),
            ("GRPC_SERVER_PORT", Some("12345")) // Should be ignored
        ], || {
            assert_eq!(grpc_backend_port(), "54321");
        });
    }
}
