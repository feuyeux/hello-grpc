/*!
 * Hello gRPC Tauri Library Module
 * 
 * This module contains the core application logic and orchestrates
 * all components of the gRPC Tauri application.
 * 
 * Module Structure:
 * - proto: Generated gRPC protocol definitions
 * - grpc_client: gRPC client implementation with connection management
 * - config: Configuration persistence and validation
 * - commands: Tauri command handlers for frontend-backend communication
 * - platform: Platform-specific utilities and error handling
 * 
 * The application supports dual modes:
 * 1. Native Desktop: Direct gRPC communication via Rust backend
 * 2. Web Browser: HTTP gateway simulation for browser compatibility
 */

// Module declarations
pub mod proto;       // gRPC protocol definitions
pub mod grpc_client; // gRPC client implementation
pub mod config;      // Configuration management
pub mod commands;    // Tauri command handlers
pub mod platform;    // Platform-specific utilities

// Test modules (compiled only in test builds)
#[cfg(test)]
mod tests;

#[cfg(test)]
mod integration_tests;

use commands::AppState;

/// Main application runner
/// 
/// Initializes the Tauri application with:
/// - Store plugin for configuration persistence
/// - Opener plugin for external URLs
/// - Application state management
/// - All gRPC command handlers
/// 
/// This function is called from main.rs and serves as the entry point
/// for both desktop and mobile platforms (via mobile_entry_point attribute).
#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Initialize application state
    let app_state = AppState::new();
    
    // Build and configure Tauri application
    tauri::Builder::default()
        // Enable opener plugin for external URL handling
        .plugin(tauri_plugin_opener::init())
        // Enable store plugin for configuration persistence
        .plugin(tauri_plugin_store::Builder::default().build())
        // Register global application state
        .manage(app_state)
        // Register all command handlers for frontend communication
        .invoke_handler(tauri::generate_handler![
            // Configuration management commands
            commands::init_config_manager,
            commands::save_connection_settings,
            
            // Connection management commands
            commands::connect_to_server,
            
            // gRPC operation commands
            commands::unary_rpc,
            commands::server_streaming_rpc,
            commands::client_streaming_rpc,
            commands::bidirectional_streaming_rpc,
            
            // Platform utilities
            commands::get_local_ip,
        ])
        // Start the application
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
