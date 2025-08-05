/*!
 * Configuration Management Module
 * 
 * This module handles persistent storage and retrieval of application
 * configuration settings using Tauri's store plugin. It provides
 * validation, default value handling, and error recovery.
 * 
 * Key Features:
 * - Persistent storage via Tauri Store plugin
 * - Automatic validation on load/save operations
 * - Default value fallback for missing configurations
 * - Error handling with user-friendly messages
 * - Settings reset capability
 * 
 * Storage Format: JSON file in application data directory
 * File: settings.json
 * Key: "connection_settings"
 */

use crate::grpc_client::{ConnectionSettings, GrpcError};
use tauri::AppHandle;
use tauri_plugin_store::{Store, StoreExt};

/// Key used to store connection settings in the persistent store
const SETTINGS_KEY: &str = "connection_settings";
/// Filename for the settings store
const STORE_FILE: &str = "settings.json";

/// Configuration manager for persistent settings storage
/// 
/// Manages the lifecycle of application configuration settings,
/// including loading, saving, validation, and reset operations.
/// Uses Tauri's store plugin for cross-platform persistence.
pub struct ConfigManager {
    /// Tauri application handle for accessing the store
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