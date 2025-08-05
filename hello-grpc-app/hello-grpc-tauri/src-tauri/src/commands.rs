/*!
 * Tauri Command Handlers Module
 * 
 * This module defines all Tauri command handlers that serve as the bridge
 * between the frontend (JavaScript) and backend (Rust) components.
 * 
 * Command Categories:
 * 1. Configuration Management: Initialize and save settings
 * 2. Connection Management: Connect to server
 * 3. gRPC Operations: Unary, streaming (server/client/bidirectional)
 * 4. Platform Utilities: IP detection for client configuration
 * 
 * Architecture Pattern:
 * Frontend (JS) → Tauri IPC → Commands → AppState → gRPC Client → Server
 * 
 * Note: Only commands actually used by the frontend are included.
 * Unused platform-specific commands have been removed for simplicity.
 */

use crate::config::ConfigManager;
use crate::grpc_client::{ConnectionSettings, GrpcClient, SharedGrpcClient};
use crate::proto::hello::{TalkRequest, TalkResponse};
use serde::Serialize;
use std::sync::Arc;
use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

/// Global application state shared across all command handlers
/// 
/// Contains the gRPC client instance and configuration manager,
/// both wrapped in Arc<Mutex<>> for thread-safe access across
/// multiple concurrent command invocations.
pub struct AppState {
    /// Shared gRPC client instance for server communication
    pub grpc_client: SharedGrpcClient,
    /// Configuration manager for settings persistence
    pub config_manager: Arc<Mutex<Option<ConfigManager>>>,
}

impl AppState {
    /// Create new application state with default settings
    pub fn new() -> Self {
        let default_settings = ConnectionSettings::default();
        Self {
            grpc_client: Arc::new(Mutex::new(GrpcClient::new(default_settings))),
            config_manager: Arc::new(Mutex::new(None)),
        }
    }
}

// ============================================================================
// Event Payloads for Streaming Operations
// ============================================================================

/// Event payload for streaming response events
/// 
/// Emitted when a new response is received during streaming operations.
/// Contains the actual response data and stream identifier for tracking.
#[derive(Clone, Serialize)]
pub struct StreamingResponseEvent {
    pub response: TalkResponse,
    pub stream_id: String,
}

/// Event payload for streaming completion events
/// 
/// Emitted when a streaming operation completes successfully.
/// Indicates that no more responses will be received for this stream.
#[derive(Clone, Serialize)]
pub struct StreamingCompleteEvent {
    pub stream_id: String,
    pub message: String,
}

/// Event payload for streaming error events
/// 
/// Emitted when an error occurs during streaming operations.
/// Contains error details and stream identifier for troubleshooting.
#[derive(Clone, Serialize)]
pub struct StreamingErrorEvent {
    pub stream_id: String,
    pub error: String,
}

/// Event payload for connection status changes
/// 
/// Emitted when connection status changes (connected/disconnected).
/// Contains current connection state and settings for UI updates.
#[derive(Clone, Serialize)]
pub struct ConnectionStatusEvent {
    pub connected: bool,
    pub settings: ConnectionSettings,
}

// ============================================================================
// Configuration Management Commands
// ============================================================================

/// Initialize the configuration manager with app handle
/// 
/// This command must be called first before using any configuration-related
/// commands. It sets up the configuration manager with the Tauri app handle
/// required for persistent storage operations.
/// 
/// # Arguments
/// * `app_handle` - Tauri application handle for accessing storage
/// * `state` - Application state containing config manager
/// 
/// # Returns
/// * `Ok(())` - Configuration manager initialized successfully
/// * `Err(String)` - Initialization failed with error message
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

// ============================================================================
// Connection Management Commands
// ============================================================================

/// Connect to the gRPC server using current settings
/// 
/// Establishes a connection to the gRPC server and emits connection status
/// events to notify the frontend of connection state changes.
/// 
/// # Arguments
/// * `state` - Application state containing gRPC client
/// * `app_handle` - Tauri handle for emitting events
/// 
/// # Returns
/// * `Ok(ConnectionSettings)` - Connected successfully with settings
/// * `Err(String)` - Connection failed with error message
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

// ============================================================================
// Configuration Management Commands (Continued)
// ============================================================================

/// Save connection settings to persistent storage
/// 
/// Persists the provided connection settings and updates the gRPC client
/// with the new configuration. Emits a connection status event to notify
/// the frontend of the settings change.
/// 
/// # Arguments
/// * `settings` - New connection settings to save
/// * `state` - Application state containing config manager and gRPC client
/// * `app_handle` - Tauri handle for emitting events
/// 
/// # Returns
/// * `Ok(())` - Settings saved successfully
/// * `Err(String)` - Failed to save settings with error message
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

// ============================================================================
// gRPC Operation Commands
// ============================================================================

/// Execute a unary RPC call (single request → single response)
/// 
/// This is the simplest gRPC operation pattern where the client sends
/// one request and receives one response synchronously.
/// 
/// # Arguments
/// * `request` - The talk request to send to the server
/// * `state` - Application state containing gRPC client
/// 
/// # Returns
/// * `Ok(TalkResponse)` - Server response data
/// * `Err(String)` - RPC call failed with error message
#[tauri::command]
pub async fn unary_rpc(
    request: TalkRequest,
    state: State<'_, AppState>,
) -> Result<TalkResponse, String> {
    let mut client = state.grpc_client.lock().await;
    
    client.unary_call(request).await
        .map_err(|e| format!("Unary RPC failed: {}", e))
}

/// Execute a server streaming RPC call (single request → multiple responses)
/// 
/// The client sends one request and the server responds with a stream of
/// responses. Events are emitted for each response received and when the
/// stream completes or encounters an error.
/// 
/// # Arguments
/// * `request` - The talk request to send to the server
/// * `stream_id` - Unique identifier for tracking this stream
/// * `state` - Application state containing gRPC client
/// * `app_handle` - Tauri handle for emitting streaming events
/// 
/// # Returns
/// * `Ok(())` - Stream initiated successfully (responses come via events)
/// * `Err(String)` - Failed to initiate stream
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

// ============================================================================
// Platform Utilities Commands  
// ============================================================================

/// Get local IP address for client configuration
/// 
/// Attempts to retrieve the local machine's IP address for use as default
/// server host. Falls back to 'localhost' if IP detection fails.
/// On Android, returns the emulator host IP (10.0.2.2) to access the host machine.
/// 
/// # Returns
/// * `Ok(String)` - Local IP address, 'localhost' fallback, or '10.0.2.2' for Android
/// * `Err(String)` - Should not occur (always returns Ok with fallback)
#[tauri::command]
pub async fn get_local_ip() -> Result<String, String> {
    use std::net::{IpAddr, Ipv4Addr};
    
    // On Android, use the special emulator host IP to access the host machine
    #[cfg(target_os = "android")]
    {
        return Ok("10.0.2.2".to_string());
    }
    
    // For other platforms, try to get the local IP address
    #[cfg(not(target_os = "android"))]
    {
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
}

/// Get platform/system information for display in the UI
/// 
/// Returns a user-friendly platform identifier that matches the format
/// used by the Flutter app for consistency across different client types.
/// 
/// # Returns
/// * `Ok(String)` - Platform identifier (e.g., "macOS", "Windows", "Linux")
/// * `Err(String)` - Should not occur (always returns Ok with platform info)
#[tauri::command]
pub async fn get_system_info() -> Result<String, String> {
    #[cfg(target_os = "macos")]
    return Ok("macOS".to_string());
    
    #[cfg(target_os = "windows")]
    return Ok("Windows".to_string());
    
    #[cfg(target_os = "linux")]
    return Ok("Linux".to_string());
    
    #[cfg(target_os = "android")]
    return Ok("Android".to_string());
    
    #[cfg(target_os = "ios")]
    return Ok("iOS".to_string());
    
    #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "linux", target_os = "android", target_os = "ios")))]
    return Ok("Unknown".to_string());
}