/*!
 * Protocol Buffer Definitions Module
 * 
 * This module includes the generated Rust code from Protocol Buffer (.proto)
 * definitions using tonic's build system. It provides the gRPC service
 * definitions, message types, and client/server stubs.
 * 
 * Generated Components:
 * - LandingServiceClient: gRPC client for hello service
 * - TalkRequest/TalkResponse: Message types for communication
 * - Streaming types: For server/client/bidirectional streaming
 * 
 * Build Process:
 * 1. .proto files → build.rs → tonic-build → Generated Rust code
 * 2. Generated code is included via tonic::include_proto! macro
 * 3. Re-exported for use throughout the application
 * 
 * Protocol Definition: ../proto/hello.proto
 */

// Generated proto code will be included here
pub mod hello {
    tonic::include_proto!("hello");
}

// Re-export all generated types for convenient access
pub use hello::*;