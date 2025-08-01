use crate::config::ConfigManager;
use crate::grpc_client::{ConnectionSettings, GrpcClient, SharedGrpcClient};
use crate::platform::{PlatformManager, PlatformInfo};
use crate::proto::hello::{TalkRequest, TalkResponse};
use serde::Serialize;
use std::sync::Arc;
use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

// Application state
pub struct AppState {
    pub grpc_client: SharedGrpcClient,
    pub config_manager: Arc<Mutex<Option<ConfigManager>>>,
}

impl AppState {
    pub fn new() -> Self {
        let default_settings = ConnectionSettings::default();
        Self {
            grpc_client: Arc::new(Mutex::new(GrpcClient::new(default_settings))),
            config_manager: Arc::new(Mutex::new(None)),
        }
    }
}

// Event payloads for streaming operations
#[derive(Clone, Serialize)]
pub struct StreamingResponseEvent {
    pub response: TalkResponse,
    pub stream_id: String,
}

#[derive(Clone, Serialize)]
pub struct StreamingCompleteEvent {
    pub stream_id: String,
    pub message: String,
}

#[derive(Clone, Serialize)]
pub struct StreamingErrorEvent {
    pub stream_id: String,
    pub error: String,
}

#[derive(Clone, Serialize)]
pub struct ConnectionStatusEvent {
    pub connected: bool,
    pub settings: ConnectionSettings,
}

// Initialize the config manager with app handle
#[tauri::command]
pub async fn init_config_manager(
    app_handle: AppHandle,
    state: State<'_, AppState>,
) -> Result<(), String> {
    let config_manager = ConfigManager::new(app_handle);
    
    // Load existing settings and update client
    match config_manager.load_settings().await {
        Ok(settings) => {
            let mut client = state.grpc_client.lock().await;
            client.update_settings(settings);
            
            let mut config_guard = state.config_manager.lock().await;
            *config_guard = Some(config_manager);
            
            Ok(())
        }
        Err(e) => Err(format!("Failed to initialize config manager: {}", e)),
    }
}

// Connection management commands
#[tauri::command]
pub async fn connect_to_server(
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<ConnectionSettings, String> {
    let mut client = state.grpc_client.lock().await;
    
    match client.connect().await {
        Ok(()) => {
            let settings = client.settings.clone();
            let _ = app_handle.emit("connection-status-changed", ConnectionStatusEvent {
                connected: true,
                settings: settings.clone(),
            });
            Ok(settings)
        }
        Err(e) => {
            let _ = app_handle.emit("connection-status-changed", ConnectionStatusEvent {
                connected: false,
                settings: client.settings.clone(),
            });
            Err(format!("Failed to connect: {}", e))
        }
    }
}

#[tauri::command]
pub async fn disconnect_from_server(
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<(), String> {
    let mut client = state.grpc_client.lock().await;
    client.disconnect().await;
    
    let _ = app_handle.emit("connection-status-changed", ConnectionStatusEvent {
        connected: false,
        settings: client.settings.clone(),
    });
    
    Ok(())
}

#[tauri::command]
pub async fn get_connection_status(state: State<'_, AppState>) -> Result<ConnectionStatusEvent, String> {
    let client = state.grpc_client.lock().await;
    Ok(ConnectionStatusEvent {
        connected: client.is_connected(),
        settings: client.settings.clone(),
    })
}

// Configuration management commands
#[tauri::command]
pub async fn save_connection_settings(
    settings: ConnectionSettings,
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<(), String> {
    let config_guard = state.config_manager.lock().await;
    let config_manager = config_guard.as_ref()
        .ok_or("Config manager not initialized")?;
    
    config_manager.save_settings(&settings).await
        .map_err(|e| format!("Failed to save settings: {}", e))?;
    
    // Update client with new settings
    let mut client = state.grpc_client.lock().await;
    client.update_settings(settings.clone());
    
    let _ = app_handle.emit("connection-status-changed", ConnectionStatusEvent {
        connected: client.is_connected(),
        settings,
    });
    
    Ok(())
}

#[tauri::command]
pub async fn load_connection_settings(
    state: State<'_, AppState>,
) -> Result<ConnectionSettings, String> {
    let config_guard = state.config_manager.lock().await;
    let config_manager = config_guard.as_ref()
        .ok_or("Config manager not initialized")?;
    
    config_manager.load_settings().await
        .map_err(|e| format!("Failed to load settings: {}", e))
}

#[tauri::command]
pub async fn reset_connection_settings(
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<ConnectionSettings, String> {
    let config_guard = state.config_manager.lock().await;
    let config_manager = config_guard.as_ref()
        .ok_or("Config manager not initialized")?;
    
    let settings = config_manager.reset_settings().await
        .map_err(|e| format!("Failed to reset settings: {}", e))?;
    
    // Update client with reset settings
    let mut client = state.grpc_client.lock().await;
    client.update_settings(settings.clone());
    
    let _ = app_handle.emit("connection-status-changed", ConnectionStatusEvent {
        connected: client.is_connected(),
        settings: settings.clone(),
    });
    
    Ok(settings)
}

// gRPC operation commands
#[tauri::command]
pub async fn unary_rpc(
    request: TalkRequest,
    state: State<'_, AppState>,
) -> Result<TalkResponse, String> {
    let mut client = state.grpc_client.lock().await;
    
    client.unary_call(request).await
        .map_err(|e| format!("Unary RPC failed: {}", e))
}

#[tauri::command]
pub async fn server_streaming_rpc(
    request: TalkRequest,
    stream_id: String,
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<(), String> {
    let mut client = state.grpc_client.lock().await;
    
    let stream = client.server_streaming_call(request).await
        .map_err(|e| format!("Server streaming RPC failed: {}", e))?;
    
    // Release the client lock before processing the stream
    drop(client);
    
    // Process the stream in a separate task
    let stream_id_clone = stream_id.clone();
    let app_handle_clone = app_handle.clone();
    
    tokio::spawn(async move {
        let mut stream = stream;
        
        loop {
            match stream.message().await {
                Ok(Some(response)) => {
                    let _ = app_handle_clone.emit("streaming-response", StreamingResponseEvent {
                        response,
                        stream_id: stream_id_clone.clone(),
                    });
                }
                Ok(None) => {
                    let _ = app_handle_clone.emit("streaming-complete", StreamingCompleteEvent {
                        stream_id: stream_id_clone.clone(),
                        message: "Stream completed successfully".to_string(),
                    });
                    break;
                }
                Err(e) => {
                    let _ = app_handle_clone.emit("streaming-error", StreamingErrorEvent {
                        stream_id: stream_id_clone.clone(),
                        error: format!("Stream error: {}", e),
                    });
                    break;
                }
            }
        }
    });
    
    Ok(())
}

#[tauri::command]
pub async fn client_streaming_rpc(
    requests: Vec<TalkRequest>,
    stream_id: String,
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<(), String> {
    let mut client = state.grpc_client.lock().await;
    
    let (sender, handle) = client.client_streaming_call().await
        .map_err(|e| format!("Client streaming RPC failed: {}", e))?;
    
    // Release the client lock
    drop(client);
    
    let stream_id_clone = stream_id.clone();
    let app_handle_clone = app_handle.clone();
    
    // Send requests in a separate task
    tokio::spawn(async move {
        for request in requests {
            if sender.send(request).await.is_err() {
                let _ = app_handle_clone.emit("streaming-error", StreamingErrorEvent {
                    stream_id: stream_id_clone.clone(),
                    error: "Failed to send request".to_string(),
                });
                return;
            }
            // Small delay between requests
            sleep(Duration::from_millis(100)).await;
        }
        // Close the sender to signal end of stream
        drop(sender);
    });
    
    // Handle the response
    tokio::spawn(async move {
        match handle.await {
            Ok(Ok(response)) => {
                let _ = app_handle.emit("streaming-response", StreamingResponseEvent {
                    response,
                    stream_id: stream_id.clone(),
                });
                let _ = app_handle.emit("streaming-complete", StreamingCompleteEvent {
                    stream_id,
                    message: "Client streaming completed successfully".to_string(),
                });
            }
            Ok(Err(e)) => {
                let _ = app_handle.emit("streaming-error", StreamingErrorEvent {
                    stream_id,
                    error: format!("Client streaming error: {}", e),
                });
            }
            Err(e) => {
                let _ = app_handle.emit("streaming-error", StreamingErrorEvent {
                    stream_id,
                    error: format!("Task join error: {}", e),
                });
            }
        }
    });
    
    Ok(())
}

#[tauri::command]
pub async fn bidirectional_streaming_rpc(
    requests: Vec<TalkRequest>,
    stream_id: String,
    state: State<'_, AppState>,
    app_handle: AppHandle,
) -> Result<(), String> {
    let mut client = state.grpc_client.lock().await;
    
    let (sender, mut receiver) = client.bidirectional_streaming_call().await
        .map_err(|e| format!("Bidirectional streaming RPC failed: {}", e))?;
    
    // Release the client lock
    drop(client);
    
    let stream_id_clone = stream_id.clone();
    let app_handle_clone = app_handle.clone();
    
    // Send requests in a separate task
    let sender_task = tokio::spawn(async move {
        for request in requests {
            if sender.send(request).await.is_err() {
                break;
            }
            // Small delay between requests
            sleep(Duration::from_millis(500)).await;
        }
        // Close the sender to signal end of stream
        drop(sender);
    });
    
    // Receive responses in another task
    let receiver_task = tokio::spawn(async move {
        while let Some(result) = receiver.recv().await {
            match result {
                Ok(response) => {
                    let _ = app_handle_clone.emit("streaming-response", StreamingResponseEvent {
                        response,
                        stream_id: stream_id_clone.clone(),
                    });
                }
                Err(status) => {
                    let _ = app_handle_clone.emit("streaming-error", StreamingErrorEvent {
                        stream_id: stream_id_clone.clone(),
                        error: format!("Stream error: {}", status),
                    });
                    break;
                }
            }
        }
        
        let _ = app_handle_clone.emit("streaming-complete", StreamingCompleteEvent {
            stream_id: stream_id_clone,
            message: "Bidirectional streaming completed".to_string(),
        });
    });
    
    // Wait for both tasks to complete
    tokio::spawn(async move {
        let _ = tokio::join!(sender_task, receiver_task);
    });
    
    Ok(())
}

// Utility command for testing connection
#[tauri::command]
pub async fn test_connection(
    state: State<'_, AppState>,
) -> Result<String, String> {
    let test_request = TalkRequest {
        data: "0".to_string(),
        meta: "rust-test".to_string(),
    };
    
    let mut client = state.grpc_client.lock().await;
    
    match client.unary_call(test_request).await {
        Ok(response) => Ok(format!("Connection test successful. Status: {}", response.status)),
        Err(e) => Err(format!("Connection test failed: {}", e)),
    }
}

// Platform-specific commands
#[tauri::command]
pub async fn get_platform_info() -> Result<PlatformInfo, String> {
    Ok(PlatformManager::get_platform_info())
}

#[tauri::command]
pub async fn validate_connection_settings(
    settings: ConnectionSettings,
) -> Result<(), String> {
    match PlatformManager::validate_network_config(settings.use_tls, &settings.server) {
        Ok(()) => Ok(()),
        Err(e) => Err(PlatformManager::get_user_friendly_error(&e)),
    }
}

#[tauri::command]
pub async fn get_platform_recommendations() -> Result<Vec<(String, String)>, String> {
    Ok(crate::platform::get_recommended_settings())
}

#[tauri::command]
pub async fn handle_platform_error(error_message: String) -> Result<String, String> {
    // Try to parse the error and provide platform-specific guidance
    let user_friendly = if error_message.contains("connection refused") {
        match PlatformManager::get_platform_info().platform {
            crate::platform::Platform::Android => {
                "Connection refused. Make sure the server is running and use 10.0.2.2 for Android emulator or your device's IP address.".to_string()
            }
            crate::platform::Platform::Ios => {
                "Connection refused. Make sure the server is running and accessible from the iOS simulator/device.".to_string()
            }
            crate::platform::Platform::Desktop => {
                "Connection refused. Make sure the server is running and accessible.".to_string()
            }
        }
    } else if error_message.contains("network") || error_message.contains("dns") {
        "Network error. Please check your internet connection and server address.".to_string()
    } else if error_message.contains("tls") || error_message.contains("ssl") {
        "TLS/SSL error. Please check your security settings and certificate configuration.".to_string()
    } else {
        format!("Error: {}", error_message)
    };
    
    Ok(user_friendly)
}

#[tauri::command]
pub async fn get_local_ip() -> Result<String, String> {
    use std::net::{IpAddr, Ipv4Addr};
    
    // Try to get the local IP address
    match local_ip_address::local_ip() {
        Ok(IpAddr::V4(ip)) => {
            // Skip loopback addresses
            if ip != Ipv4Addr::new(127, 0, 0, 1) {
                Ok(ip.to_string())
            } else {
                Ok("localhost".to_string())
            }
        }
        Ok(IpAddr::V6(_)) => {
            // For IPv6, fallback to localhost for simplicity
            Ok("localhost".to_string())
        }
        Err(_) => {
            // Fallback to localhost if we can't determine the local IP
            Ok("localhost".to_string())
        }
    }
}