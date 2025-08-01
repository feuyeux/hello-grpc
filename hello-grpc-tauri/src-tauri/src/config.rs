use crate::grpc_client::{ConnectionSettings, GrpcError};
use serde_json::Value;
use std::collections::HashMap;
use tauri::AppHandle;
use tauri_plugin_store::{Store, StoreExt};

const SETTINGS_KEY: &str = "connection_settings";
const STORE_FILE: &str = "settings.json";

pub struct ConfigManager {
    app_handle: AppHandle,
}

impl ConfigManager {
    pub fn new(app_handle: AppHandle) -> Self {
        Self { app_handle }
    }

    fn get_store(&self) -> Result<std::sync::Arc<Store<tauri::Wry>>, GrpcError> {
        self.app_handle
            .store(STORE_FILE)
            .map_err(|e| GrpcError::ConfigError(format!("Failed to access store: {}", e)))
    }

    pub async fn save_settings(&self, settings: &ConnectionSettings) -> Result<(), GrpcError> {
        settings.validate()?;
        
        let store = self.get_store()?;
        let settings_value = serde_json::to_value(settings)?;
        
        store.set(SETTINGS_KEY, settings_value);
        store.save()
            .map_err(|e| GrpcError::ConfigError(format!("Failed to save settings: {}", e)))?;
        
        Ok(())
    }

    pub async fn load_settings(&self) -> Result<ConnectionSettings, GrpcError> {
        let store = self.get_store()?;
        
        match store.get(SETTINGS_KEY) {
            Some(value) => {
                let settings: ConnectionSettings = serde_json::from_value(value.clone())?;
                settings.validate()?;
                Ok(settings)
            }
            None => {
                // Return default settings if none exist
                let default_settings = ConnectionSettings::default();
                // Save default settings for future use
                self.save_settings(&default_settings).await?;
                Ok(default_settings)
            }
        }
    }

    pub async fn reset_settings(&self) -> Result<ConnectionSettings, GrpcError> {
        let default_settings = ConnectionSettings::default();
        self.save_settings(&default_settings).await?;
        Ok(default_settings)
    }

    pub async fn update_setting(&self, key: &str, value: Value) -> Result<ConnectionSettings, GrpcError> {
        let mut settings = self.load_settings().await?;
        
        match key {
            "server" => {
                if let Some(server) = value.as_str() {
                    settings.server = server.to_string();
                } else {
                    return Err(GrpcError::ConfigError("Server must be a string".to_string()));
                }
            }
            "port" => {
                if let Some(port) = value.as_u64() {
                    if port > 0 && port <= 65535 {
                        settings.port = port as u16;
                    } else {
                        return Err(GrpcError::ConfigError("Port must be between 1 and 65535".to_string()));
                    }
                } else {
                    return Err(GrpcError::ConfigError("Port must be a number".to_string()));
                }
            }
            "use_tls" => {
                if let Some(use_tls) = value.as_bool() {
                    settings.use_tls = use_tls;
                } else {
                    return Err(GrpcError::ConfigError("use_tls must be a boolean".to_string()));
                }
            }
            "timeout_seconds" => {
                if let Some(timeout) = value.as_u64() {
                    if timeout > 0 {
                        settings.timeout_seconds = timeout;
                    } else {
                        return Err(GrpcError::ConfigError("Timeout must be greater than 0".to_string()));
                    }
                } else {
                    return Err(GrpcError::ConfigError("Timeout must be a number".to_string()));
                }
            }
            _ => {
                return Err(GrpcError::ConfigError(format!("Unknown setting key: {}", key)));
            }
        }
        
        self.save_settings(&settings).await?;
        Ok(settings)
    }

    pub async fn get_all_settings(&self) -> Result<HashMap<String, Value>, GrpcError> {
        let settings = self.load_settings().await?;
        let mut map = HashMap::new();
        
        map.insert("server".to_string(), Value::String(settings.server));
        map.insert("port".to_string(), Value::Number(settings.port.into()));
        map.insert("use_tls".to_string(), Value::Bool(settings.use_tls));
        map.insert("timeout_seconds".to_string(), Value::Number(settings.timeout_seconds.into()));
        
        Ok(map)
    }
}

#[cfg(test)]
mod tests {
    use super::*;


    fn create_test_settings() -> ConnectionSettings {
        ConnectionSettings {
            server: "test.example.com".to_string(),
            port: 8080,
            use_tls: true,
            timeout_seconds: 60,
        }
    }

    #[test]
    fn test_connection_settings_validation() {
        let valid_settings = create_test_settings();
        assert!(valid_settings.validate().is_ok());

        let invalid_server = ConnectionSettings {
            server: "".to_string(),
            ..valid_settings.clone()
        };
        assert!(invalid_server.validate().is_err());

        let invalid_port = ConnectionSettings {
            port: 0,
            ..valid_settings.clone()
        };
        assert!(invalid_port.validate().is_err());

        let invalid_timeout = ConnectionSettings {
            timeout_seconds: 0,
            ..valid_settings
        };
        assert!(invalid_timeout.validate().is_err());
    }

    #[test]
    fn test_endpoint_url_generation() {
        let http_settings = ConnectionSettings {
            server: "localhost".to_string(),
            port: 9996,
            use_tls: false,
            timeout_seconds: 30,
        };
        assert_eq!(http_settings.get_endpoint_url(), "http://localhost:9996");

        let https_settings = ConnectionSettings {
            server: "secure.example.com".to_string(),
            port: 443,
            use_tls: true,
            timeout_seconds: 30,
        };
        assert_eq!(https_settings.get_endpoint_url(), "https://secure.example.com:443");
    }
}