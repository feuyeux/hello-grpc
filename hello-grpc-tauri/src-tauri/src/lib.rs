pub mod proto;
pub mod grpc_client;
pub mod config;
pub mod commands;
pub mod platform;

#[cfg(test)]
mod tests;

#[cfg(test)]
mod integration_tests;

use commands::AppState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = AppState::new();
    
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::init_config_manager,
            commands::connect_to_server,
            commands::disconnect_from_server,
            commands::get_connection_status,
            commands::save_connection_settings,
            commands::load_connection_settings,
            commands::reset_connection_settings,
            commands::unary_rpc,
            commands::server_streaming_rpc,
            commands::client_streaming_rpc,
            commands::bidirectional_streaming_rpc,
            commands::test_connection,
            commands::get_platform_info,
            commands::validate_connection_settings,
            commands::get_platform_recommendations,
            commands::handle_platform_error,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
