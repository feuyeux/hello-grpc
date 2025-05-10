use std::error::Error;
use std::time::Duration;

use futures::stream;
use log::{error, info};
use tokio::time;
use tonic::transport::Channel;
use tonic::Request;

use hello_grpc_rust::common::conn::{build_client, CONFIG_PATH};
use hello_grpc_rust::common::landing::landing_service_client::LandingServiceClient;
use hello_grpc_rust::common::landing::{TalkRequest, TalkResponse};
use hello_grpc_rust::common::utils::{build_link_requests, random_id};

/// Client application entry point for demonstrating the gRPC calls.
/// Executes all four RPC patterns in sequence.
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Initialize logging
    log4rs::init_file(CONFIG_PATH, Default::default())?;
    info!("Starting gRPC client");

    // Build the client connection
    // build_client() returns the client directly, not a Result
    let mut client = build_client().await;
    info!("Successfully connected to gRPC server");

    // Execute all four gRPC RPC patterns sequentially
    info!("Executing all gRPC communication patterns...");
    
    // 1. Unary RPC
    if let Err(error) = talk(&mut client).await {
        error!("Unary RPC failed: {}", error);
    }

    // 2. Server Streaming RPC
    if let Err(error) = talk_one_answer_more(&mut client).await {
        error!("Server Streaming RPC failed: {}", error);
    }

    // 3. Client Streaming RPC
    if let Err(error) = talk_more_answer_one(&mut client).await {
        error!("Client Streaming RPC failed: {}", error);
    }

    // 4. Bidirectional Streaming RPC
    if let Err(error) = talk_bidirectional(&mut client).await {
        error!("Bidirectional Streaming RPC failed: {}", error);
    }

    info!("All gRPC operations completed");
    Ok(())
}

/// Performs a bidirectional streaming RPC call.
/// Client streams multiple requests while receiving multiple responses.
async fn talk_bidirectional(
    client: &mut LandingServiceClient<Channel>,
) -> Result<(), Box<dyn Error>> {
    info!("Executing Bidirectional Streaming RPC (TalkBidirectional)");
    
    // Configure how many requests to send with a delay between each
    let mut interval = time::interval(Duration::from_secs(1));
    let request_count = 3;
    let mut remaining = request_count;
    
    // Create an outbound stream of requests
    let outbound = async_stream::stream! {
        while remaining > 0 {
            // Wait for the next interval tick
            interval.tick().await;
            
            // Create a new request with random data
            let request = TalkRequest { 
                data: random_id(5), 
                meta: "RUST".to_string() 
            };
            
            info!("Sending bidirectional request #{}: data={}, meta=RUST", 
                 request_count - remaining + 1, request.data);
                 
            yield request;
            remaining -= 1;
        }
    };

    // Add headers to the request
    let mut request = Request::new(outbound);
    request.metadata_mut().insert("request-id", format!("bid-{}", uuid::Uuid::new_v4()).parse()?);
    
    // Send the stream of requests
    let response = client.talk_bidirectional(request).await?;
    let mut inbound = response.into_inner();
    
    // Process each response as it arrives
    let mut response_count = 0;
    while let Some(response_item) = inbound.message().await? {
        response_count += 1;
        info!("Received bidirectional response #{}", response_count);
        print_response(&response_item);
    }
    
    info!("Bidirectional streaming completed: sent {} requests, received {} responses", 
          request_count, response_count);
    
    Ok(())
}

/// Performs a client streaming RPC call.
/// Client sends multiple requests and receives a single response.
async fn talk_more_answer_one(
    client: &mut LandingServiceClient<Channel>,
) -> Result<(), Box<dyn Error>> {
    info!("Executing Client Streaming RPC (TalkMoreAnswerOne)");
    
    // Build a list of requests to send
    let requests = build_link_requests();
    let request_count = requests.len();
    
    info!("Sending {} requests in client streaming mode", request_count);
    
    // Add headers to the request stream
    let mut request = Request::new(stream::iter(requests));
    request.metadata_mut().insert("request-id", format!("cs-{}", uuid::Uuid::new_v4()).parse()?);
    
    // Send the requests and process the response
    match client.talk_more_answer_one(request).await {
        Ok(response) => {
            let response_inner = response.into_inner();
            info!("Received response for client streaming call: status={}", response_inner.status);
            print_response(&response_inner);
            Ok(())
        },
        Err(status) => {
            error!("Client streaming call failed: {}", status);
            Err(status.into())
        }
    }
}

/// Performs a server streaming RPC call.
/// Client sends a single request and receives multiple responses.
async fn talk_one_answer_more(
    client: &mut LandingServiceClient<Channel>,
) -> Result<(), Box<dyn Error>> {
    info!("Executing Server Streaming RPC (TalkOneAnswerMore)");
    
    // Create a request with multiple indices to process
    let mut request = Request::new(TalkRequest {
        data: "0,1,2".to_string(),
        meta: "RUST".to_string(),
    });
    
    info!("Sending request with data=\"0,1,2\", meta=\"RUST\"");
    
    // Add headers to the request
    request.metadata_mut().insert("request-id", format!("ss-{}", uuid::Uuid::new_v4()).parse()?);
    
    // Send the request and get a stream of responses
    let mut stream = client.talk_one_answer_more(request).await?.into_inner();
    
    // Process each response in the stream
    let mut response_count = 0;
    while let Some(response) = stream.message().await? {
        response_count += 1;
        info!("Received server streaming response #{}", response_count);
        print_response(&response);
    }
    
    info!("Server streaming completed: received {} responses", response_count);
    Ok(())
}

/// Performs a unary RPC call.
/// Client sends a single request and receives a single response.
async fn talk(client: &mut LandingServiceClient<Channel>) -> Result<(), Box<dyn Error>> {
    info!("Executing Unary RPC (Talk)");
    
    // Create a simple request
    let message = TalkRequest {
        data: "0".to_string(),
        meta: "RUST".to_string(),
    };
    
    info!("Sending unary request: data=\"0\", meta=\"RUST\"");
    
    // Add headers to the request
    let mut request = Request::new(message);
    request.metadata_mut().insert("request-id", format!("unary-{}", uuid::Uuid::new_v4()).parse()?);
    
    // Send the request
    let response = client.talk(request).await?;
    
    info!("Received unary response: status={}", response.get_ref().status);
    print_response(response.get_ref());
    
    Ok(())
}

/// Formats and logs a TalkResponse object, extracting key fields from the result map.
fn print_response(response: &TalkResponse) {
    for (i, result) in response.results.iter().enumerate() {
        let result_map = &result.kv;
        
        // Extract values from the key-value map with safe defaults
        let meta = result_map.get("meta").map_or("", |v| v.as_str());
        let _id = result_map.get("id").map_or("", |v| v.as_str());
        let idx = result_map.get("idx").map_or("", |v| v.as_str());
        let data = result_map.get("data").map_or("", |v| v.as_str());
        
        // Log the response details
        info!(
            "Result #{}: status={}, id={}, type={}, meta={}, request_idx={}, data={}",
            i + 1,
            response.status,
            result.id,
            result.r#type,
            meta,
            idx,
            data
        );
    }
}
