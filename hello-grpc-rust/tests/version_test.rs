use hello_grpc_rust::common::utils::get_version;

// To see the printed output, run:
// cargo test --test version_test -- --nocapture

#[test]
fn test_get_version() {
    // Get the version string
    let version = get_version();
    
    // Test that the version string starts with the expected prefix
    assert!(version.starts_with("tonic.version="));
    
    // Test that the version is not empty (beyond the prefix)
    assert!(version.len() > 13); // "grpc.version=" is 13 characters
    
    // Print the version for verification - only visible when using --nocapture
    println!("Rust gRPC version: {}", version);
}