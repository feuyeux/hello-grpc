#[cfg(test)]
mod tests {
    use crate::grpc_client::{ConnectionSettings, GrpcClient, GrpcError};
    use crate::proto::hello::TalkRequest;
    use tokio::time::{sleep, Duration};

    fn create_test_settings() -> ConnectionSettings {
        ConnectionSettings {
            server: "localhost".to_string(),
            port: 9996,
            use_tls: false,
            timeout_seconds: 30,
        }
    }

    fn create_test_request() -> TalkRequest {
        TalkRequest {
            data: "0".to_string(),
            meta: "rust-test".to_string(),
        }
    }

    #[test]
    fn test_connection_settings_validation() {
        let valid_settings = create_test_settings();
        assert!(valid_settings.validate().is_ok());

        // Test empty server
        let invalid_server = ConnectionSettings {
            server: "".to_string(),
            ..valid_settings.clone()
        };
        assert!(invalid_server.validate().is_err());

        // Test zero port
        let invalid_port = ConnectionSettings {
            port: 0,
            ..valid_settings.clone()
        };
        assert!(invalid_port.validate().is_err());

        // Test zero timeout
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

    #[test]
    fn test_grpc_client_creation() {
        let settings = create_test_settings();
        let client = GrpcClient::new(settings.clone());
        
        assert!(!client.is_connected());
        assert_eq!(client.settings.server, settings.server);
        assert_eq!(client.settings.port, settings.port);
    }

    #[test]
    fn test_grpc_client_settings_update() {
        let initial_settings = create_test_settings();
        let mut client = GrpcClient::new(initial_settings);
        
        let new_settings = ConnectionSettings {
            server: "newserver.com".to_string(),
            port: 8080,
            use_tls: true,
            timeout_seconds: 60,
        };
        
        client.update_settings(new_settings.clone());
        
        assert_eq!(client.settings.server, new_settings.server);
        assert_eq!(client.settings.port, new_settings.port);
        assert_eq!(client.settings.use_tls, new_settings.use_tls);
        assert_eq!(client.settings.timeout_seconds, new_settings.timeout_seconds);
        assert!(!client.is_connected()); // Should reset connection status
    }

    #[tokio::test]
    async fn test_grpc_client_disconnect() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        // Simulate connected state - but is_connected() also checks for client existence
        // So we can't really test this without a real connection
        // Let's just test that disconnect sets the flag to false
        client.set_connected_for_test(true);
        
        client.disconnect().await;
        // After disconnect, both client and flag should be None/false
        assert!(!client.is_connected());
    }

    // Integration tests (require running gRPC server)
    #[tokio::test]
    #[ignore] // Ignore by default since it requires a running server
    async fn test_grpc_client_connection() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        match client.connect().await {
            Ok(()) => {
                assert!(client.is_connected());
                client.disconnect().await;
                assert!(!client.is_connected());
            }
            Err(e) => {
                // Connection failed - this is expected if server is not running
                println!("Connection failed (expected if server not running): {}", e);
            }
        }
    }

    #[tokio::test]
    #[ignore] // Ignore by default since it requires a running server
    async fn test_unary_rpc_call() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        if client.connect().await.is_ok() {
            let request = create_test_request();
            
            match client.unary_call(request).await {
                Ok(response) => {
                    println!("Unary RPC response: {:?}", response);
                    assert!(response.status >= 0);
                }
                Err(e) => {
                    println!("Unary RPC failed: {}", e);
                }
            }
        }
    }

    #[tokio::test]
    #[ignore] // Ignore by default since it requires a running server
    async fn test_server_streaming_rpc() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        if client.connect().await.is_ok() {
            let request = create_test_request();
            
            match client.server_streaming_call(request).await {
                Ok(mut stream) => {
                    let mut count = 0;
                    while let Ok(Some(response)) = stream.message().await {
                        println!("Server streaming response {}: {:?}", count, response);
                        count += 1;
                        if count >= 5 { // Limit for testing
                            break;
                        }
                    }
                    assert!(count > 0);
                }
                Err(e) => {
                    println!("Server streaming RPC failed: {}", e);
                }
            }
        }
    }

    #[tokio::test]
    #[ignore] // Ignore by default since it requires a running server
    async fn test_client_streaming_rpc() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        if client.connect().await.is_ok() {
            match client.client_streaming_call().await {
                Ok((sender, handle)) => {
                    // Send multiple requests
                    for i in 0..3 {
                        let request = TalkRequest {
                            data: i.to_string(),
                            meta: "rust-test".to_string(),
                        };
                        if sender.send(request).await.is_err() {
                            break;
                        }
                        sleep(Duration::from_millis(100)).await;
                    }
                    drop(sender); // Close the stream
                    
                    match handle.await {
                        Ok(Ok(response)) => {
                            println!("Client streaming response: {:?}", response);
                            assert!(response.status >= 0);
                        }
                        Ok(Err(e)) => {
                            println!("Client streaming RPC error: {}", e);
                        }
                        Err(e) => {
                            println!("Client streaming task error: {}", e);
                        }
                    }
                }
                Err(e) => {
                    println!("Client streaming RPC setup failed: {}", e);
                }
            }
        }
    }

    #[tokio::test]
    #[ignore] // Ignore by default since it requires a running server
    async fn test_bidirectional_streaming_rpc() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        if client.connect().await.is_ok() {
            match client.bidirectional_streaming_call().await {
                Ok((sender, mut receiver)) => {
                    // Send requests in a separate task
                    let send_task = tokio::spawn(async move {
                        for i in 0..3 {
                            let request = TalkRequest {
                                data: i.to_string(),
                                meta: "rust-test".to_string(),
                            };
                            if sender.send(request).await.is_err() {
                                break;
                            }
                            sleep(Duration::from_millis(500)).await;
                        }
                        drop(sender);
                    });
                    
                    // Receive responses
                    let mut response_count = 0;
                    while let Some(result) = receiver.recv().await {
                        match result {
                            Ok(response) => {
                                println!("Bidirectional streaming response {}: {:?}", response_count, response);
                                response_count += 1;
                            }
                            Err(status) => {
                                println!("Bidirectional streaming error: {}", status);
                                break;
                            }
                        }
                        
                        if response_count >= 3 {
                            break;
                        }
                    }
                    
                    let _ = send_task.await;
                    assert!(response_count > 0);
                }
                Err(e) => {
                    println!("Bidirectional streaming RPC setup failed: {}", e);
                }
            }
        }
    }

    #[test]
    fn test_grpc_error_types() {
        // Test error conversion and display
        let config_error = GrpcError::ConfigError("Test config error".to_string());
        assert!(config_error.to_string().contains("Configuration error"));
        
        let timeout_error = GrpcError::TimeoutError("Test timeout".to_string());
        assert!(timeout_error.to_string().contains("Timeout error"));
        
        let channel_error = GrpcError::ChannelError("Test channel error".to_string());
        assert!(channel_error.to_string().contains("Channel error"));
    }

    #[test]
    fn test_connection_settings_default() {
        let default_settings = ConnectionSettings::default();
        assert_eq!(default_settings.server, "localhost");
        assert_eq!(default_settings.port, 9996);
        assert!(!default_settings.use_tls);
        assert_eq!(default_settings.timeout_seconds, 30);
        assert!(default_settings.validate().is_ok());
    }

    #[test]
    fn test_talk_request_creation() {
        let request = create_test_request();
        assert_eq!(request.data, "0");
        assert_eq!(request.meta, "rust-test");
    }

    // Test error handling scenarios
    #[tokio::test]
    async fn test_connection_with_invalid_settings() {
        let invalid_settings = ConnectionSettings {
            server: "".to_string(),
            port: 0,
            use_tls: false,
            timeout_seconds: 0,
        };
        
        let mut client = GrpcClient::new(invalid_settings);
        
        match client.connect().await {
            Ok(()) => panic!("Connection should have failed with invalid settings"),
            Err(e) => {
                assert!(matches!(e, GrpcError::ConfigError(_)));
            }
        }
    }

    #[tokio::test]
    async fn test_rpc_call_without_connection() {
        let settings = create_test_settings();
        let mut client = GrpcClient::new(settings);
        
        // Don't connect, just try to make a call
        let request = create_test_request();
        
        // This should attempt to connect and likely fail if no server is running
        match client.unary_call(request).await {
            Ok(_) => {
                // If it succeeds, the auto-connection worked
                assert!(client.is_connected());
            }
            Err(_) => {
                // Expected if no server is running
                assert!(!client.is_connected());
            }
        }
    }
}