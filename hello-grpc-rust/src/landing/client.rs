/// gRPC Client implementation for the Landing service (Rust).
///
/// This client demonstrates all four gRPC communication patterns:
/// 1. Unary RPC
/// 2. Server streaming RPC
/// 3. Client streaming RPC
/// 4. Bidirectional streaming RPC
///
/// The implementation follows standardized patterns for error handling,
/// logging, and graceful shutdown.

use std::error::Error;
use std::time::{Duration, Instant};

use futures::stream;
use log::{error, info};
use tokio::time;
use tonic::transport::Channel;
use tonic::Request;

use hello_grpc_rust::common::conn::{build_client, CONFIG_PATH};
use hello_grpc_rust::common::landing::landing_service_client::LandingServiceClient;
use hello_grpc_rust::common::landing::{TalkRequest, TalkResponse};
use hello_grpc_rust::common::utils::{build_link_requests, get_version, random_id};

// Configuration constants
const RETRY_ATTEMPTS: u32 = 3;
const RETRY_DELAY_SECONDS: u64 = 2;
const ITERATION_COUNT: u32 = 3;
const REQUEST_DELAY_MS: u64 = 200;
const SEND_DELAY_MS: u64 = 2;
const REQUEST_TIMEOUT_SECONDS: u64 = 5;
const DEFAULT_BATCH_SIZE: usize = 5;

/// Client application entry point
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize rustls crypto provider
    let _ = rustls::crypto::ring::default_provider().install_default();
    
    // Initialize logging
    log4rs::init_file(CONFIG_PATH, Default::default())?;
    
    info!("Starting gRPC client [version: {}]", get_version());

    // Retry logic for connection
    for attempt in 1..=RETRY_ATTEMPTS {
        match connect_and_run(attempt).await {
            Ok(success) => {
                if success {
                    break;
                }
            }
            Err(e) => {
                error!("Connection attempt {} failed: {}", attempt, e);
                if attempt < RETRY_ATTEMPTS {
                    info!("Retrying in {} seconds...", RETRY_DELAY_SECONDS);
                    time::sleep(Duration::from_secs(RETRY_DELAY_SECONDS)).await;
                }
            }
        }
    }

    info!("Client execution completed successfully");
    Ok(())
}

/// Connect to server and run all gRPC patterns
async fn connect_and_run(attempt: u32) -> Result<bool, Box<dyn Error>> {
    info!("Connection attempt {}/{}", attempt, RETRY_ATTEMPTS);

    let mut client = build_client().await;
    info!("Successfully connected to gRPC server");

    run_grpc_calls(&mut client, REQUEST_DELAY_MS, ITERATION_COUNT).await
}

/// Run all gRPC call patterns multiple times
async fn run_grpc_calls(
    client: &mut LandingServiceClient<Channel>,
    delay_ms: u64,
    iterations: u32,
) -> Result<bool, Box<dyn Error>> {
    for iteration in 1..=iterations {
        info!("====== Starting iteration {}/{} ======", iteration, iterations);

        // 1. Unary RPC
        info!("----- Executing unary RPC -----");
        execute_unary_call(client).await?;

        // 2. Server streaming RPC
        info!("----- Executing server streaming RPC -----");
        execute_server_streaming_call(client).await?;

        // 3. Client streaming RPC
        info!("----- Executing client streaming RPC -----");
        let response = execute_client_streaming_call(client).await?;
        log_response(&response);

        // 4. Bidirectional streaming RPC
        info!("----- Executing bidirectional streaming RPC -----");
        execute_bidirectional_streaming_call(client).await?;

        if iteration < iterations {
            info!("Waiting {}ms before next iteration...", delay_ms);
            time::sleep(Duration::from_millis(delay_ms)).await;
        }
    }

    info!("All gRPC calls completed successfully");
    Ok(true)
}

/// Execute unary RPC call
async fn execute_unary_call(
    client: &mut LandingServiceClient<Channel>,
) -> Result<(), Box<dyn Error>> {
    let request_id = format!("unary-{}", uuid::Uuid::new_v4());
    
    let message = TalkRequest {
        data: "0".to_string(),
        meta: "RUST".to_string(),
    };

    info!("Sending unary request: data={}, meta=RUST", message.data);
    let start_time = Instant::now();

    let mut request = Request::new(message);
    request.metadata_mut().insert("request-id", request_id.parse()?);
    request.metadata_mut().insert("client", "rust-client".parse()?);
    request.set_timeout(Duration::from_secs(REQUEST_TIMEOUT_SECONDS));

    match client.talk(request).await {
        Ok(response) => {
            let duration = start_time.elapsed();
            info!("Unary call successful in {}ms", duration.as_millis());
            log_response(response.get_ref());
            Ok(())
        }
        Err(status) => {
            log_error(&status, &request_id, "Talk");
            Err(status.into())
        }
    }
}

/// Execute server streaming RPC call
async fn execute_server_streaming_call(
    client: &mut LandingServiceClient<Channel>,
) -> Result<(), Box<dyn Error>> {
    let request_id = format!("server-stream-{}", uuid::Uuid::new_v4());
    
    let message = TalkRequest {
        data: "0,1,2".to_string(),
        meta: "RUST".to_string(),
    };

    info!("Starting server streaming with request: data={}, meta=RUST", message.data);
    let start_time = Instant::now();

    let mut request = Request::new(message);
    request.metadata_mut().insert("request-id", request_id.parse()?);
    request.metadata_mut().insert("client", "rust-client".parse()?);

    match client.talk_one_answer_more(request).await {
        Ok(response) => {
            let mut stream = response.into_inner();
            let mut response_count = 0;

            while let Some(response) = stream.message().await? {
                response_count += 1;
                info!("Received server streaming response #{}:", response_count);
                log_response(&response);
            }

            let duration = start_time.elapsed();
            info!(
                "Server streaming completed: received {} responses in {}ms",
                response_count,
                duration.as_millis()
            );
            Ok(())
        }
        Err(status) => {
            log_error(&status, &request_id, "TalkOneAnswerMore");
            Err(status.into())
        }
    }
}

/// Execute client streaming RPC call
async fn execute_client_streaming_call(
    client: &mut LandingServiceClient<Channel>,
) -> Result<TalkResponse, Box<dyn Error>> {
    let request_id = format!("client-stream-{}", uuid::Uuid::new_v4());
    
    let requests = build_link_requests();
    let request_count = requests.len();

    info!("Starting client streaming with {} requests", request_count);
    let start_time = Instant::now();

    let mut request = Request::new(stream::iter(requests));
    request.metadata_mut().insert("request-id", request_id.parse()?);
    request.metadata_mut().insert("client", "rust-client".parse()?);

    match client.talk_more_answer_one(request).await {
        Ok(response) => {
            let duration = start_time.elapsed();
            info!(
                "Client streaming completed: sent {} requests in {}ms",
                request_count,
                duration.as_millis()
            );
            Ok(response.into_inner())
        }
        Err(status) => {
            log_error(&status, &request_id, "TalkMoreAnswerOne");
            Err(status.into())
        }
    }
}

/// Execute bidirectional streaming RPC call
async fn execute_bidirectional_streaming_call(
    client: &mut LandingServiceClient<Channel>,
) -> Result<(), Box<dyn Error>> {
    let request_id = format!("bidirectional-{}", uuid::Uuid::new_v4());
    
    info!("Starting bidirectional streaming with {} requests", DEFAULT_BATCH_SIZE);
    let start_time = Instant::now();

    // Create an outbound stream of requests
    let mut interval = time::interval(Duration::from_millis(SEND_DELAY_MS));
    let mut remaining = DEFAULT_BATCH_SIZE;
    
    let outbound = async_stream::stream! {
        let mut request_count = 0;
        while remaining > 0 {
            interval.tick().await;
            
            request_count += 1;
            let request = TalkRequest {
                data: random_id(5),
                meta: "RUST".to_string(),
            };
            
            info!(
                "Sending bidirectional streaming request #{}: data={}, meta=RUST",
                request_count, request.data
            );
            
            yield request;
            remaining -= 1;
        }
    };

    let mut request = Request::new(outbound);
    request.metadata_mut().insert("request-id", request_id.parse()?);
    request.metadata_mut().insert("client", "rust-client".parse()?);

    match client.talk_bidirectional(request).await {
        Ok(response) => {
            let mut inbound = response.into_inner();
            let mut response_count = 0;

            while let Some(response_item) = inbound.message().await? {
                response_count += 1;
                info!("Received bidirectional streaming response #{}:", response_count);
                log_response(&response_item);
            }

            let duration = start_time.elapsed();
            info!(
                "Bidirectional streaming completed in {}ms",
                duration.as_millis()
            );
            Ok(())
        }
        Err(status) => {
            log_error(&status, &request_id, "TalkBidirectional");
            Err(status.into())
        }
    }
}

/// Log response details
fn log_response(response: &TalkResponse) {
    info!(
        "Response status: {}, results: {}",
        response.status,
        response.results.len()
    );

    for (i, result) in response.results.iter().enumerate() {
        let result_map = &result.kv;
        
        let meta = result_map.get("meta").map_or("", |v| v.as_str());
        let id = result_map.get("id").map_or("", |v| v.as_str());
        let idx = result_map.get("idx").map_or("", |v| v.as_str());
        let data = result_map.get("data").map_or("", |v| v.as_str());
        
        info!(
            "  Result #{}: id={}, type={}, meta={}, id={}, idx={}, data={}",
            i + 1,
            result.id,
            result.r#type,
            meta,
            id,
            idx,
            data
        );
    }
}

/// Log error with context
fn log_error(status: &tonic::Status, request_id: &str, method: &str) {
    error!(
        "Request failed - request_id: {}, method: {}, error_code: {:?}, message: {}",
        request_id,
        method,
        status.code(),
        status.message()
    );
}
