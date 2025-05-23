use chrono::prelude::*;
use futures::stream;
use futures::{Stream, StreamExt};
use log::{debug, error, info};
use std::collections::HashMap;
use std::env;
use std::error::Error;
use std::pin::Pin;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{mpsc, Mutex};
use tonic::{
    metadata::{KeyAndValueRef, MetadataMap},
    transport::{Channel, Identity, Server, ServerTlsConfig},
    IntoRequest, Request, Response, Status, Streaming,
};
use uuid::Uuid;

use hello_grpc_rust::common::conn::{build_client, grpc_backend_host, has_backend, CONFIG_PATH};
use hello_grpc_rust::common::landing::landing_service_client::LandingServiceClient;
use hello_grpc_rust::common::landing::landing_service_server::{
    LandingService, LandingServiceServer,
};
use hello_grpc_rust::common::landing::{ResultType, TalkRequest, TalkResponse, TalkResult};
use hello_grpc_rust::common::trans::{CERT_CHAIN, CERT_KEY, TRACING_KEYS};
use hello_grpc_rust::common::utils::{get_version, thanks, HELLOS};

// Add a lightweight metrics collector
struct ServerMetrics {
    requests_total: std::sync::atomic::AtomicUsize,
    errors_total: std::sync::atomic::AtomicUsize,
    last_request_time: Mutex<Option<DateTime<Utc>>>,
}

impl ServerMetrics {
    fn new() -> Self {
        ServerMetrics {
            requests_total: std::sync::atomic::AtomicUsize::new(0),
            errors_total: std::sync::atomic::AtomicUsize::new(0),
            last_request_time: Mutex::new(None),
        }
    }

    async fn record_request(&self) {
        self.requests_total.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let mut last_time = self.last_request_time.lock().await;
        *last_time = Some(Utc::now());
    }

    fn record_error(&self) {
        self.errors_total.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    }

    async fn get_stats(&self) -> HashMap<String, String> {
        let mut stats = HashMap::new();
        stats.insert(
            "requests_total".to_string(),
            self.requests_total.load(std::sync::atomic::Ordering::Relaxed).to_string(),
        );
        stats.insert(
            "errors_total".to_string(),
            self.errors_total.load(std::sync::atomic::Ordering::Relaxed).to_string(),
        );
        if let Some(last_time) = *self.last_request_time.lock().await {
            stats.insert(
                "last_request_time".to_string(),
                last_time.to_rfc3339(),
            );
        }
        stats
    }
}

// Configure connection pool size and timeouts
const CONNECTION_POOL_SIZE: usize = 5;
const REQUEST_TIMEOUT_MS: u64 = 5000;
const GRACEFUL_SHUTDOWN_TIMEOUT_MS: u64 = 10000;

/// Main entry point for the gRPC server.
/// Configures and starts the server with appropriate TLS settings if enabled.
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize logging
    log4rs::init_file(CONFIG_PATH, Default::default())?;

    let address = format!("[::0]:{}", get_server_port()).parse()?;
    let is_tls = env::var("GRPC_HELLO_SECURE").unwrap_or_default();

    // Configure server with or without TLS
    let mut server = if is_tls == "Y" {
        let cert = tokio::fs::read(CERT_CHAIN).await?;
        let key = tokio::fs::read(CERT_KEY).await?;
        let identity = Identity::from_pem(cert, key);
        
        info!(
            "Starting gRPC TLS server on port {} [version: {}]",
            get_server_port(),
            get_version()
        );
        
        Server::builder()
            .tls_config(ServerTlsConfig::new().identity(identity))?
            .timeout(Duration::from_millis(REQUEST_TIMEOUT_MS)) // Add request timeout
    } else {
        info!(
            "Starting gRPC server on port {} [version: {}]",
            get_server_port(),
            get_version()
        );
        
        Server::builder()
            .timeout(Duration::from_millis(REQUEST_TIMEOUT_MS)) // Add request timeout
    };

    // Create shared metrics
    let metrics = Arc::new(ServerMetrics::new());
    
    // Create connection pool if backend is configured
    let client_pool = if has_backend() {
        info!(
            "Operating in proxy mode with backend at {} (pool size: {})",
            grpc_backend_host(),
            CONNECTION_POOL_SIZE
        );
        
        let mut pool = Vec::with_capacity(CONNECTION_POOL_SIZE);
        for i in 0..CONNECTION_POOL_SIZE {
            // build_client() returns the client directly, not a Result
            let client = build_client().await;
            pool.push(Some(client));
            info!("Created connection #{} in pool", i);
        }
        
        Some(Arc::new(Mutex::new(pool)))
    } else {
        info!("Operating in standalone mode (no backend)");
        None
    };

    // Create service implementation
    let service = LandingServiceServer::new(ProtoServer {
        backend: if has_backend() { grpc_backend_host() } else { "".to_string() },
        client_pool,
        metrics: metrics.clone(),
    });

    // Add metrics endpoint
    let metrics_clone = metrics.clone();
    tokio::spawn(async move {
        let metrics_address = format!("[::0]:{}", get_server_port().parse::<u16>().unwrap_or(50051) + 1).parse().unwrap();
        info!("Starting metrics server on port {}", get_server_port().parse::<u16>().unwrap_or(50051) + 1);
        
        let make_service = hyper::service::make_service_fn(move |_| {
            let metrics = metrics_clone.clone();
            async move {
                Ok::<_, hyper::Error>(hyper::service::service_fn(move |_req| {
                    let metrics = metrics.clone();                async move {
                    let stats = metrics.get_stats().await;
                    let mut response = String::new();
                    for (k, v) in stats {
                        response.push_str(&format!("{}={}\n", k, v));
                    }
                    
                    Ok::<_, hyper::Error>(hyper::Response::new(hyper::Body::from(response)))
                }
                }))
            }
        });
        
        let server = hyper::Server::bind(&metrics_address).serve(make_service);
        if let Err(e) = server.await {
            error!("Metrics server error: {}", e);
        }
    });

    // Create the server future
    let server_future = server.add_service(service).serve(address);
    
    // Use a separate future for shutdown signal
    let shutdown = shutdown_signal();
    
    // Wait for either server completion or shutdown signal
    tokio::select! {
        result = server_future => {
            // This branch should only execute if the server encounters an error
            error!("Server exited unexpectedly: {:?}", result);
        }
        _ = shutdown => {
            info!("Server shutting down gracefully");
        }
    }

    // Wait for any ongoing requests to complete (maximum wait time)
    tokio::time::sleep(Duration::from_millis(GRACEFUL_SHUTDOWN_TIMEOUT_MS)).await;
    info!("Server shutdown complete");

    Ok(())
}

/// Waits for termination signals to initiate graceful shutdown.
/// Handles CTRL+C on all platforms and SIGTERM on Unix platforms.
async fn shutdown_signal() {
    // Wait for CTRL+C
    tokio::signal::ctrl_c()
        .await
        .expect("Failed to install CTRL+C signal handler");

    // Wait for SIGTERM
    #[cfg(unix)]
    {
        let mut sigterm = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
            .expect("Failed to install SIGTERM signal handler");

        tokio::select! {
            _ = sigterm.recv() => {
                info!("Received SIGTERM signal");
            }
            _ = tokio::signal::ctrl_c() => {
                info!("Received second CTRL+C signal");
            }
        }
    }

    #[cfg(not(unix))]
    {
        tokio::signal::ctrl_c()
            .await
            .expect("Failed to install second CTRL+C signal handler");
        info!("Received second CTRL+C signal");
    }
}

/// Gets the server port from environment or uses default.
fn get_server_port() -> String {
    env::var("GRPC_SERVER_PORT").unwrap_or_else(|_| "9996".to_string())
}

// Helper function to propagate tracing headers
fn propagate_headers(request: &mut Request<TalkRequest>) -> MetadataMap {
    let mut headers_map = MetadataMap::new();
    
    // First collect the values we need to copy
    let mut values_to_copy = Vec::new();
    for key_name in &TRACING_KEYS {
        if let Some(value) = request.metadata().get(*key_name) {
            debug!("Propagating tracing header: {}={:?}", key_name, value);
            values_to_copy.push((*key_name, value.clone()));
        }
    }
    
    // Now insert the values into both maps
    for (key, value) in values_to_copy {
        request.metadata_mut().insert(key, value.clone());
        headers_map.insert(key, value);
    }
    
    headers_map
}

// Helper function to log metadata
fn log_metadata(method: &str, metadata: &MetadataMap) {
    debug!("Method: {} Metadata:", method);
    for key_and_value in metadata.iter() {
        match key_and_value {
            KeyAndValueRef::Ascii(key, value) => {
                debug!("  {}: {:?}", key.as_str(), value);
            }
            KeyAndValueRef::Binary(key, value) => {
                debug!("  {}-bin: {:?}", key.as_str(), value);
            }
        }
    }
}

// Helper function to create response
fn create_response(data: String) -> TalkResult {
    // Try to parse the input data as an index into the HELLOS array
    let index = data.parse::<usize>().unwrap_or(0) % HELLOS.len();
    let hello = HELLOS[index];
    
    // Create a map for the key-value pairs in the result
    let mut result_map = HashMap::new();
    result_map.insert("id".to_string(), Uuid::new_v4().to_string());
    result_map.insert("idx".to_string(), data);
    
    // Build the data string with greeting and response
    let mut response_data = hello.to_string();
    response_data.push_str(",");
    response_data.push_str(thanks(hello));
    
    result_map.insert("data".to_string(), response_data);
    result_map.insert("meta".to_string(), "RUST".to_string());
    
    TalkResult {
        id: Utc::now().timestamp_millis(),
        r#type: ResultType::Ok as i32,
        kv: result_map,
    }
}

/// Implementation of the gRPC LandingService.
/// Can operate either as a standalone server or as a proxy to a backend service.
pub struct ProtoServer {
    /// The address of the backend service, empty if operating in standalone mode
    backend: String,
    /// Pool of clients for communicating with the backend service
    client_pool: Option<Arc<Mutex<Vec<Option<LandingServiceClient<Channel>>>>>>,
    /// Server metrics collector
    metrics: Arc<ServerMetrics>,
}

impl ProtoServer {
    // Helper method to get a client from the connection pool
    async fn get_client(&self) -> Option<LandingServiceClient<Channel>> {
        if let Some(pool) = &self.client_pool {
            let mut pool_guard = pool.lock().await;
            
            // Find an available client in the pool
            for client_opt in pool_guard.iter_mut() {
                if let Some(client) = client_opt {
                    // Clone the client for use
                    return Some(client.clone());
                }
            }
            
            // If no clients available, try to create a new one
            // build_client() returns the client directly, not a Result
            let client = build_client().await;
            
            // Try to replace a None slot if available
            for client_opt in pool_guard.iter_mut() {
                if client_opt.is_none() {
                    *client_opt = Some(client.clone());
                    return Some(client);
                }
            }
            Some(client)
        } else {
            None
        }
    }
}

#[tonic::async_trait]
impl LandingService for ProtoServer {
    /// Implements the unary RPC method 'Talk'.
    async fn talk(
        &self,
        mut request: Request<TalkRequest>,
    ) -> Result<Response<TalkResponse>, Status> {
        self.metrics.record_request().await;
        
        let talk_request = request.get_ref();
        let data = &talk_request.data;
        let meta = &talk_request.meta;
        info!("Unary call received - data: {}, meta: {}", data, meta);
        log_metadata("Talk", request.metadata());

        // If backend is configured, proxy the request
        if !self.backend.is_empty() {
            // Propagate tracing headers
            propagate_headers(&mut request);
            
            match self.get_client().await {
                Some(mut client) => {
                    // Set timeout for the backend request
                    let mut req = request.into_request();
                    req.set_timeout(Duration::from_millis(REQUEST_TIMEOUT_MS - 500)); // Slightly shorter than server timeout
                    
                    match client.talk(req).await {
                        Ok(response) => {
                            let talk_response = response.get_ref();
                            info!("Proxy response received from backend");
                            Ok(Response::new(talk_response.clone()))
                        },
                        Err(status) => {
                            error!("Backend call failed: {}", status);
                            self.metrics.record_error();
                            Err(status)
                        }
                    }
                },
                None => {
                    error!("Backend configured but client not available");
                    self.metrics.record_error();
                    Err(Status::internal("Backend connection not available"))
                }
            }
        } else {
            // Process locally
            let result = create_response(data.clone());
            let response = TalkResponse {
                status: 200,
                results: vec![result],
            };
            Ok(Response::new(response))
        }
    }

    /// Stream type for server streaming responses
    type TalkOneAnswerMoreStream =
        Pin<Box<dyn Stream<Item = Result<TalkResponse, Status>> + Send + Sync + 'static>>;

    /// Implements the server streaming RPC method 'TalkOneAnswerMore'.
    async fn talk_one_answer_more(
        &self,
        request: Request<TalkRequest>,
    ) -> Result<Response<Self::TalkOneAnswerMoreStream>, Status> {
        let talk_request = request.get_ref();
        info!(
            "Server streaming call received - data: {}, meta: {}", 
            talk_request.data, talk_request.meta
        );
        log_metadata("TalkOneAnswerMore", request.metadata());
        
        let (tx, rx) = mpsc::channel(4);
        
        // If backend is configured, proxy the request
        if !self.backend.is_empty() {
            if let Some(client) = self.get_client().await {
                let mut client_clone = client.clone();
                
                match client_clone.talk_one_answer_more(request).await {
                    Ok(response) => {
                        let mut stream = response.into_inner();
                        
                        // Spawn a task to forward responses from backend to client
                        tokio::spawn(async move {
                            while let Some(result) = stream.message().await.unwrap_or(None) {
                                if tx.send(Ok(result)).await.is_err() {
                                    break;
                                }
                            }
                        });
                    },
                    Err(status) => {
                        error!("Backend streaming call failed: {}", status);
                        return Err(status);
                    }
                }
            } else {
                error!("Backend configured but client not available");
                return Err(Status::internal("Backend connection not available"));
            }
        } else {
            // Process locally
            let data = talk_request.data.clone();
            
            // Spawn a task to send multiple responses
            tokio::spawn(async move {
                for data_part in data.split(',') {
                    let result = create_response(data_part.to_string());
                    let response = TalkResponse {
                        status: 200,
                        results: vec![result],
                    };
                    
                    if tx.send(Ok(response)).await.is_err() {
                        break;
                    }
                }
            });
        }
        
        // Return the receiver stream
        Ok(Response::new(Box::pin(
            tokio_stream::wrappers::ReceiverStream::new(rx),
        )))
    }

    /// Implements the client streaming RPC method 'TalkMoreAnswerOne'.
    async fn talk_more_answer_one(
        &self,
        request: Request<Streaming<TalkRequest>>,
    ) -> Result<Response<TalkResponse>, Status> {
        info!("Client streaming call received");
        log_metadata("TalkMoreAnswerOne", request.metadata());
        
        let mut inbound_stream = request.into_inner();
        
        // If backend is configured, proxy the request
        if !self.backend.is_empty() {
            if let Some(client) = self.get_client().await {
                let mut client_clone = client.clone();
                let mut requests = Vec::new();
                
                // Collect all incoming requests
                while let Some(result) = inbound_stream.next().await {
                    match result {
                        Ok(request) => requests.push(request),
                        Err(status) => {
                            error!("Error receiving client stream: {}", status);
                            return Err(status);
                        }
                    }
                }
                
                // Forward collected requests to backend
                let outbound = Request::new(stream::iter(requests));
                
                match client_clone.talk_more_answer_one(outbound).await {
                    Ok(response) => Ok(Response::new(response.into_inner())),
                    Err(status) => {
                        error!("Backend client streaming call failed: {}", status);
                        Err(status)
                    }
                }
            } else {
                error!("Backend configured but client not available");
                Err(Status::internal("Backend connection not available"))
            }
        } else {
            // Process locally
            let mut results = Vec::new();
            
            // Process each incoming request
            while let Some(result) = inbound_stream.next().await {
                match result {
                    Ok(request) => {
                        info!("Client stream item - data: {}, meta: {}", request.data, request.meta);
                        results.push(create_response(request.data));
                    },
                    Err(status) => {
                        error!("Error receiving client stream: {}", status);
                        return Err(status);
                    }
                }
            }
            
            let response = TalkResponse {
                status: 200,
                results,
            };
            
            Ok(Response::new(response))
        }
    }

    /// Stream type for bidirectional streaming responses
    type TalkBidirectionalStream =
        Pin<Box<dyn Stream<Item = Result<TalkResponse, Status>> + Send + 'static>>;

    /// Implements the bidirectional streaming RPC method 'TalkBidirectional'.
    async fn talk_bidirectional(
        &self,
        request: Request<Streaming<TalkRequest>>,
    ) -> Result<Response<Self::TalkBidirectionalStream>, Status> {
        info!("Bidirectional streaming call received");
        log_metadata("TalkBidirectional", request.metadata());
        
        let mut request_stream = request.into_inner();
        
        // If backend is configured, proxy the request
        if !self.backend.is_empty() {
            if let Some(client) = self.get_client().await {
                let mut client_clone = client.clone();
                let (tx, rx) = mpsc::channel(4);
                
                // Collect all incoming requests
                let mut requests = Vec::new();
                while let Some(result) = request_stream.next().await {
                    match result {
                        Ok(request) => requests.push(request),
                        Err(status) => {
                            error!("Error receiving bidirectional stream: {}", status);
                            return Err(status);
                        }
                    }
                }
                
                // Forward collected requests to backend
                let outbound = Request::new(stream::iter(requests));
                
                match client_clone.talk_bidirectional(outbound).await {
                    Ok(response) => {
                        let mut response_stream = response.into_inner();
                        
                        // Spawn a task to forward responses
                        tokio::spawn(async move {
                            while let Some(result) = response_stream.message().await.unwrap_or(None) {
                                if tx.send(Ok(result)).await.is_err() {
                                    break;
                                }
                            }
                        });
                        
                        Ok(Response::new(Box::pin(
                            tokio_stream::wrappers::ReceiverStream::new(rx),
                        )))
                    },
                    Err(status) => {
                        error!("Backend bidirectional streaming call failed: {}", status);
                        Err(status)
                    }
                }
            } else {
                error!("Backend configured but client not available");
                Err(Status::internal("Backend connection not available"))
            }
        } else {
            // Process locally
            let output = async_stream::try_stream! {
                while let Some(result) = request_stream.next().await {
                    match result {
                        Ok(request) => {
                            info!("Bidirectional stream item - data: {}, meta: {}", request.data, request.meta);
                            let result = create_response(request.data);
                            yield TalkResponse {
                                status: 200,
                                results: vec![result],
                            };
                        },
                        Err(status) => Err(status)?
                    }
                }
            };
            
            Ok(Response::new(Box::pin(output)))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*; // Access ProtoServer, LandingService trait, etc.
    use crate::common::landing::{TalkRequest, TalkResponse, ResultType, LandingServiceClient}; // Added LandingServiceClient for pool
    use crate::common::utils; // For HELLOS, thanks
    use tonic::Request;
    use std::collections::HashMap;
    use std::sync::Arc;
    use tokio::sync::Mutex as TokioMutex; // Alias for tokio's Mutex
    use tokio_stream::wrappers::ReceiverStream; // For creating streams from mpsc
    use tokio::sync::mpsc; // For mpsc channels
    use futures::stream::iter as futures_iter; // For creating a stream from an iterator

    // Helper to create a default ProtoServer for non-proxy tests
    fn new_test_server() -> ProtoServer {
        ProtoServer {
            backend: String::new(), // Empty backend for non-proxy mode
            client_pool: None, // No client pool needed for non-proxy tests
            metrics: Arc::new(ServerMetrics::new()),
        }
    }

    #[tokio::test]
    async fn test_talk_unary_non_proxy() {
        let server = new_test_server();
        let request_payload = TalkRequest {
            data: "0".to_string(), // Corresponds to HELLOS[0] -> "Hello"
            meta: "TestClient".to_string(),
        };
        let request = Request::new(request_payload.clone());

        match server.talk(request).await {
            Ok(response) => {
                let talk_response = response.into_inner();
                assert_eq!(talk_response.status, 200);
                assert_eq!(talk_response.results.len(), 1);
                let result = &talk_response.results[0];
                assert_eq!(result.r#type, ResultType::Ok as i32);
                
                let expected_hello = utils::HELLOS[0];
                let expected_thanks = utils::thanks(expected_hello);
                let expected_data = format!("{},{}", expected_hello, expected_thanks);

                assert_eq!(result.kv.get("data").unwrap(), &expected_data);
                assert_eq!(result.kv.get("meta").unwrap(), "RUST");
                assert_eq!(result.kv.get("idx").unwrap(), "0");
                assert!(result.kv.contains_key("id"));
            }
            Err(status) => {
                panic!("talk unary call failed: {:?}", status);
            }
        }
    }

    #[tokio::test]
    async fn test_talk_one_answer_more_non_proxy() {
        let server = new_test_server();
        let request_payload = TalkRequest {
            data: "0,1".to_string(), // Two indices
            meta: "TestClient".to_string(),
        };
        let request = Request::new(request_payload);
        let response_stream = server.talk_one_answer_more(request).await.unwrap().into_inner();
        
        let mut received_responses = Vec::new();
        let mut stream = response_stream; // Type is Pin<Box<dyn Stream<Item = Result<TalkResponse, Status>> + Send + Sync + 'static>>
        while let Some(res_result) = stream.next().await {
            match res_result {
                Ok(resp) => received_responses.push(resp),
                Err(status) => panic!("Stream error: {:?}", status),
            }
        }

        assert_eq!(received_responses.len(), 2, "Expected 2 responses for data '0,1'");

        // Check first response (for data "0")
        let resp1 = &received_responses[0];
        assert_eq!(resp1.status, 200);
        assert_eq!(resp1.results.len(), 1);
        let result1 = &resp1.results[0];
        let expected_hello1 = utils::HELLOS[0];
        let expected_thanks1 = utils::thanks(expected_hello1);
        assert_eq!(result1.kv.get("data").unwrap(), &format!("{},{}", expected_hello1, expected_thanks1));
        assert_eq!(result1.kv.get("idx").unwrap(), "0");

        // Check second response (for data "1")
        let resp2 = &received_responses[1];
        assert_eq!(resp2.status, 200);
        assert_eq!(resp2.results.len(), 1);
        let result2 = &resp2.results[0];
        let expected_hello2 = utils::HELLOS[1];
        let expected_thanks2 = utils::thanks(expected_hello2);
        assert_eq!(result2.kv.get("data").unwrap(), &format!("{},{}", expected_hello2, expected_thanks2));
        assert_eq!(result2.kv.get("idx").unwrap(), "1");
    }

    #[tokio::test]
    async fn test_talk_more_answer_one_non_proxy() {
        let server = new_test_server();
        let requests_data = vec![
            TalkRequest { data: "0".to_string(), meta: "Client1".to_string() },
            TalkRequest { data: "1".to_string(), meta: "Client2".to_string() },
        ];
        
        let (tx, rx) = mpsc::channel(4); // Create a channel for the stream
        let request_stream = ReceiverStream::new(rx);
        
        // Spawn a task to send requests into the channel
        tokio::spawn(async move {
            for req_data in requests_data {
                if tx.send(req_data).await.is_err() {
                    eprintln!("Receiver dropped before all messages sent");
                    return;
                }
            }
        });

        let request = Request::new(request_stream);
        match server.talk_more_answer_one(request).await {
            Ok(response) => {
                let talk_response = response.into_inner();
                assert_eq!(talk_response.status, 200);
                // The server's talk_more_answer_one aggregates results.
                // It creates a response with multiple TalkResult entries.
                assert_eq!(talk_response.results.len(), 2, "Expected 2 results in the response");

                // Check first result (from data "0")
                let result1 = &talk_response.results[0];
                let expected_hello1 = utils::HELLOS[0];
                let expected_thanks1 = utils::thanks(expected_hello1);
                assert_eq!(result1.kv.get("data").unwrap(), &format!("{},{}", expected_hello1, expected_thanks1));
                assert_eq!(result1.kv.get("idx").unwrap(), "0");

                // Check second result (from data "1")
                let result2 = &talk_response.results[1];
                let expected_hello2 = utils::HELLOS[1];
                let expected_thanks2 = utils::thanks(expected_hello2);
                assert_eq!(result2.kv.get("data").unwrap(), &format!("{},{}", expected_hello2, expected_thanks2));
                assert_eq!(result2.kv.get("idx").unwrap(), "1");
            }
            Err(status) => {
                panic!("talk_more_answer_one call failed: {:?}", status);
            }
        }
    }

    #[tokio::test]
    async fn test_talk_bidirectional_non_proxy() {
        let server = new_test_server();
        let client_requests_data = vec![
            TalkRequest { data: "0".to_string(), meta: "ClientBidi1".to_string() },
            TalkRequest { data: "1".to_string(), meta: "ClientBidi2".to_string() },
        ];

        let (tx, rx) = mpsc::channel(4);
        let request_stream = ReceiverStream::new(rx);
        
        tokio::spawn(async move {
            for req_data in client_requests_data {
                if tx.send(req_data).await.is_err() {
                    eprintln!("Bidirectional: Receiver dropped before all messages sent");
                    return;
                }
            }
        });

        let request_tonic = Request::new(request_stream);
        let response_stream_result = server.talk_bidirectional(request_tonic).await;

        match response_stream_result {
            Ok(response) => {
                let mut received_responses = Vec::new();
                let mut server_stream = response.into_inner();
                while let Some(res_result) = server_stream.next().await {
                    match res_result {
                        Ok(resp) => received_responses.push(resp),
                        Err(status) => panic!("Bidirectional stream error from server: {:?}", status),
                    }
                }

                assert_eq!(received_responses.len(), 2, "Expected 2 responses from bidirectional server stream");

                // Check first response
                let resp1 = &received_responses[0];
                assert_eq!(resp1.status, 200);
                let result1 = &resp1.results[0];
                let expected_hello1 = utils::HELLOS[0];
                let expected_thanks1 = utils::thanks(expected_hello1);
                assert_eq!(result1.kv.get("data").unwrap(), &format!("{},{}", expected_hello1, expected_thanks1));
                 assert_eq!(result1.kv.get("idx").unwrap(), "0");

                // Check second response
                let resp2 = &received_responses[1];
                assert_eq!(resp2.status, 200);
                let result2 = &resp2.results[0];
                let expected_hello2 = utils::HELLOS[1];
                let expected_thanks2 = utils::thanks(expected_hello2);
                assert_eq!(result2.kv.get("data").unwrap(), &format!("{},{}", expected_hello2, expected_thanks2));
                assert_eq!(result2.kv.get("idx").unwrap(), "1");
            }
            Err(status) => {
                panic!("talk_bidirectional call failed: {:?}", status);
            }
        }
    }

    // --- Proxy Tests Submodule ---
    #[cfg(test)]
    mod proxy_tests {
        use super::*; // Access items from the outer tests module and server module
        use std::env;
        use tonic::transport::Channel; // For the client_pool type

        // Helper to create a ProtoServer configured for proxy mode.
        // For these conceptual tests, the client_pool won't contain a usable client
        // that connects to a mock backend, so attempts to use it will likely fail
        // or rely on build_client()'s behavior if the pool is empty/unusable.
        fn new_proxy_test_server_conceptual(backend_host: &str, backend_port: &str) -> ProtoServer {
            env::set_var("GRPC_HELLO_BACKEND", backend_host);
            // grpc_backend_port() will use GRPC_HELLO_BACKEND_PORT or GRPC_SERVER_PORT or default.
            // To ensure a specific port for the backend:
            env::set_var("GRPC_HELLO_BACKEND_PORT", backend_port);
            
            // The client_pool is initialized as Some, but empty.
            // The get_client() method in ProtoServer will attempt to call build_client()
            // if it can't find a usable client in the pool.
            let client_pool = Some(Arc::new(TokioMutex::new(Vec::new()))); 

            ProtoServer {
                // The 'backend' field in ProtoServer is just a String representation, not used for connection directly by ProtoServer itself.
                // The actual connection uses GRPC_HELLO_BACKEND env var via common::conn::grpc_backend_host().
                backend: format!("{}:{}", backend_host, backend_port), 
                client_pool,
                metrics: Arc::new(ServerMetrics::new()),
            }
        }
        
        // Cleanup environment variables after tests
        fn cleanup_env_vars() {
            env::remove_var("GRPC_HELLO_BACKEND");
            env::remove_var("GRPC_HELLO_BACKEND_PORT");
        }

        #[tokio::test]
        async fn test_talk_unary_proxy_attempts_connection() {
            // This test demonstrates the proxy path is taken.
            // It doesn't use a mock backend, so it will likely try to connect
            // to a non-existent service and fail, which is an expected outcome here.
            // A full test would involve a mock backend service.

            let server = new_proxy_test_server_conceptual("localhost", "55555"); // Use a port unlikely to be in use
            let request_payload = TalkRequest {
                data: "0".to_string(),
                meta: "TestClientProxy".to_string(),
            };
            let request = Request::new(request_payload.clone());

            // We expect this to fail because no client is properly injected/mocked for the backend,
            // and no real backend is running at localhost:55555.
            // The server's get_client() will call common::conn::build_client() if the pool is empty,
            // which will then attempt a real connection.
            match server.talk(request).await {
                Ok(response) => {
                    cleanup_env_vars(); // Ensure cleanup even on panic/failure
                    panic!("Proxy call returned Ok, but expected connection error or specific mock behavior. Response: {:?}", response.into_inner());
                }
                Err(status) => {
                    // This is the expected path for this conceptual test.
                    // The error would typically be related to connection failure or service unavailable.
                    eprintln!("Proxy call failed as expected: {} (code: {:?})", status.message(), status.code());
                    assert!(
                        status.code() == tonic::Code::Unavailable ||  // If build_client fails to connect
                        status.code() == tonic::Code::Internal || // If client available but backend call fails
                        status.code() == tonic::Code::Unknown, // If build_client panics (e.g. include_str! fails in test env if files missing)
                        "Expected Unavailable, Internal, or Unknown status code, got {:?} with message: {}", status.code(), status.message()
                    );
                }
            }
            cleanup_env_vars();
        }

        // TODO: Add similar conceptual tests for other streaming RPCs in proxy mode.
        // These would follow the same pattern:
        // 1. Configure server for proxy mode.
        // 2. Send a request.
        // 3. Expect an error status (e.g., Unavailable) because the mock backend isn't running.
        //    This confirms the proxy logic path was attempted.
        //
        // Example for server streaming:
        // #[tokio::test]
        // async fn test_talk_one_answer_more_proxy_attempts_connection() {
        //     let server = new_proxy_test_server_conceptual("localhost", "55556");
        //     let request_payload = TalkRequest { data: "0".to_string(), meta: "TestClientProxyStream".to_string() };
        //     let request = Request::new(request_payload);
        //
        //     match server.talk_one_answer_more(request).await {
        //         Ok(response_stream) => {
        //             // It's possible the initial call returns Ok, but stream encounters error.
        //             // Collect responses and expect an error or empty stream.
        //             let mut stream = response_stream.into_inner();
        //             let first_item = stream.next().await;
        //             if let Some(Ok(resp)) = first_item {
        //                  cleanup_env_vars();
        //                  panic!("Proxy server stream returned data, expected error. First item: {:?}", resp);
        //             } else if first_item.is_none() {
        //                  // This could happen if the backend call succeeds but returns an empty stream,
        //                  // which is not the primary failure mode we are testing here (connection failure).
        //                  // Or if the error occurs before any messages are sent.
        //             }
        //             // If first_item is Some(Err(status)), then the assertion below handles it.
        //             // If an error is not propagated as Err(status) from the main function,
        //             // but rather as an error within the stream itself, this test needs adjustment.
        //             // The current implementation of talk_one_answer_more for proxy returns Err(Status)
        //             // if the initial backend call fails, so this panic should not be hit.
        //             cleanup_env_vars();
        //             panic!("Proxy server stream call returned Ok, but expected error status directly from method or in stream.");
        //         }
        //         Err(status) => {
        //             eprintln!("Proxy server streaming call failed as expected: {:?}", status);
        //             assert!(
        //                 status.code() == tonic::Code::Unavailable ||
        //                 status.code() == tonic::Code::Internal ||
        //                 status.code() == tonic::Code::Unknown,
        //                 "Expected Unavailable, Internal, or Unknown, got {:?}", status.code()
        //             );
        //         }
        //     }
        //     cleanup_env_vars();
        // }

        // TODO: For full proxy testing:
        //   1. Refactor ProtoServer to allow injection of a mock LandingServiceClient.
        //   2. Or, implement a mock LandingService and run it on a test port, then
        //      configure the ProtoServer's client_pool to connect to this mock service.
    }
}
