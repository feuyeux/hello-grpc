fn main() -> Result<(), Box<dyn std::error::Error>> {
    tauri_build::build();
    
    // Generate gRPC client code from proto files
    tonic_build::configure()
        .build_server(false)
        .type_attribute(".", "#[derive(serde::Serialize, serde::Deserialize)]")
        .compile_protos(&["../proto/landing.proto"], &["../proto"])?;
    
    Ok(())
}
