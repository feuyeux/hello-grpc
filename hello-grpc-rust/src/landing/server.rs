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
