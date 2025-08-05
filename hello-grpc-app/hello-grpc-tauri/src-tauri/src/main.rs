/*!
 * Hello gRPC Tauri Application Entry Point
 * 
 * This is the main entry point for the Tauri desktop application.
 * It prevents console window from showing on Windows release builds
 * and delegates execution to the library module.
 * 
 * Architecture Flow:
 * main.rs → lib.rs → AppState + Commands → gRPC Client → Server
 */

// Prevents additional console window on Windows in release builds
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

/// Application entry point
/// 
/// Calls the run function from the library module which initializes
/// the Tauri application with all required plugins and command handlers.
fn main() {
    hello_grpc_tauri_lib::run()
}
