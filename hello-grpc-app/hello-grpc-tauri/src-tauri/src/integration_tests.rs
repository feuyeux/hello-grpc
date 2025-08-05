#[cfg(test)]
mod integration_tests {
    use crate::commands::AppState;
    use crate::grpc_client::ConnectionSettings;
    use crate::proto::hello::TalkRequest;

    #[tokio::test]
    async fn test_app_state_creation() {
        let app_state = AppState::new();
        
        // Verify that the app state is created with default settings
        let client = app_state.grpc_client.lock().await;
        assert!(!client.is_connected());
        assert_eq!(client.settings.server, "localhost");
        assert_eq!(client.settings.port, 9996);
        assert!(!client.settings.use_tls);
        assert_eq!(client.settings.timeout_seconds, 30);
    }

    #[tokio::test]
    async fn test_grpc_client_settings_update() {
        let app_state = AppState::new();
        
        let new_settings = ConnectionSettings {
            server: "example.com".to_string(),
            port: 8080,
            use_tls: true,
            timeout_seconds: 60,
        };
        
        {
            let mut client = app_state.grpc_client.lock().await;
            client.update_settings(new_settings.clone());
            
            assert_eq!(client.settings.server, "example.com");
            assert_eq!(client.settings.port, 8080);
            assert!(client.settings.use_tls);
            assert_eq!(client.settings.timeout_seconds, 60);
        }
    }

    #[test]
    fn test_talk_request_serialization() {
        let request = TalkRequest {
            data: "test_data".to_string(),
            meta: "test_meta".to_string(),
        };
        
        // Test that the request can be serialized to JSON (required for Tauri commands)
        let json = serde_json::to_string(&request).expect("Failed to serialize TalkRequest");
        assert!(json.contains("test_data"));
        assert!(json.contains("test_meta"));
        
        // Test that it can be deserialized back
        let deserialized: TalkRequest = serde_json::from_str(&json).expect("Failed to deserialize TalkRequest");
        assert_eq!(deserialized.data, "test_data");
        assert_eq!(deserialized.meta, "test_meta");
    }

    #[test]
    fn test_connection_settings_serialization() {
        let settings = ConnectionSettings {
            server: "test.example.com".to_string(),
            port: 9999,
            use_tls: true,
            timeout_seconds: 45,
        };
        
        // Test that settings can be serialized to JSON
        let json = serde_json::to_string(&settings).expect("Failed to serialize ConnectionSettings");
        assert!(json.contains("test.example.com"));
        assert!(json.contains("9999"));
        assert!(json.contains("true"));
        assert!(json.contains("45"));
        
        // Test that it can be deserialized back
        let deserialized: ConnectionSettings = serde_json::from_str(&json).expect("Failed to deserialize ConnectionSettings");
        assert_eq!(deserialized.server, "test.example.com");
        assert_eq!(deserialized.port, 9999);
        assert!(deserialized.use_tls);
        assert_eq!(deserialized.timeout_seconds, 45);
    }

    #[tokio::test]
    async fn test_grpc_client_connection_validation() {
        let app_state = AppState::new();
        
        // Test with invalid settings
        let invalid_settings = ConnectionSettings {
            server: "".to_string(),
            port: 0,
            use_tls: false,
            timeout_seconds: 0,
        };
        
        {
            let mut client = app_state.grpc_client.lock().await;
            client.update_settings(invalid_settings);
            
            // Connection should fail with invalid settings
            let result = client.connect().await;
            assert!(result.is_err());
        }
    }

    #[test]
    fn test_error_handling() {
        use crate::grpc_client::GrpcError;
        
        // Test different error types
        let config_error = GrpcError::ConfigError("Test error".to_string());
        assert!(config_error.to_string().contains("Configuration error"));
        
        let timeout_error = GrpcError::TimeoutError("Timeout occurred".to_string());
        assert!(timeout_error.to_string().contains("Timeout error"));
        
        let channel_error = GrpcError::ChannelError("Channel failed".to_string());
        assert!(channel_error.to_string().contains("Channel error"));
    }
}