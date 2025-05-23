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

#[cfg(test)]
mod tests {
    use super::*; // To call talk(), talk_one_answer_more(), etc.
    use crate::common::landing::landing_service_server::{LandingService, LandingServiceServer};
    use crate::common::landing::{TalkRequest, TalkResponse, TalkResult, ResultType};
    use std::net::SocketAddr;
    use tokio::sync::{mpsc, oneshot};
    use tonic::transport::Server;
    use std::time::Duration;
    use std::collections::HashMap; // For TalkResult kv
    use std::env; // For env::var for build_test_client

    // --- Mock Landing Server ---
    #[derive(Debug)]
    struct MockLandingService {
        // Use a channel to send received unary request for assertion
        unary_req_tx: Option<mpsc::Sender<TalkRequest>>,
        // Predefined unary response
        unary_res: Option<TalkResponse>,

        // For server streaming
        server_streaming_req_tx: Option<mpsc::Sender<TalkRequest>>,
        server_streaming_res_count: usize,

        // For client streaming
        client_streaming_res: Option<TalkResponse>,
        // Use a channel to send received client stream requests for assertion
        client_streaming_collector_tx: Option<mpsc::Sender<Vec<TalkRequest>>>,


        // For bidirectional streaming
        // Channel to send received bidi requests for assertion
        bidi_req_collector_tx: Option<mpsc::Sender<Vec<TalkRequest>>>,
        // Number of messages the mock bidi server should send back
        bidi_res_count: usize,
    }

    impl Default for MockLandingService {
        fn default() -> Self {
            MockLandingService {
                unary_req_tx: None,
                unary_res: Some(TalkResponse { status: 200, results: vec![TalkResult::default()] }),
                server_streaming_req_tx: None,
                server_streaming_res_count: 1, // Default to send 1 message
                client_streaming_res: Some(TalkResponse { status: 200, results: vec![] }),
                client_streaming_collector_tx: None,
                bidi_req_collector_tx: None,
                bidi_res_count: 1,
            }
        }
    }

    #[tonic::async_trait]
    impl LandingService for MockLandingService {
        async fn talk(&self, request: Request<TalkRequest>) -> Result<Response<TalkResponse>, Status> {
            let req_inner = request.into_inner();
            if let Some(tx) = &self.unary_req_tx {
                tx.send(req_inner.clone()).await.expect("Failed to send unary req for inspection");
            }
            Ok(Response::new(self.unary_res.clone().unwrap_or_default()))
        }

        type TalkOneAnswerMoreStream = Pin<Box<dyn Stream<Item = Result<TalkResponse, Status>> + Send + Sync + 'static>>;

        async fn talk_one_answer_more(&self, request: Request<TalkRequest>) -> Result<Response<Self::TalkOneAnswerMoreStream>, Status> {
            let req_inner = request.into_inner();
             if let Some(tx) = &self.server_streaming_req_tx {
                tx.send(req_inner.clone()).await.expect("Failed to send server_streaming req for inspection");
            }
            let count = self.server_streaming_res_count;
            let (tx, rx) = mpsc::channel(count + 1); // Use count for channel size
            tokio::spawn(async move {
                for i in 0..count {
                    let response = TalkResponse {
                        status: 200,
                        results: vec![TalkResult {
                            kv: {
                                let mut map = HashMap::new();
                                map.insert("data".to_string(), format!("Mock Server Stream Msg {}", i+1));
                                map
                            },
                            ..Default::default()
                        }],
                    };
                    tx.send(Ok(response)).await.unwrap();
                }
            });
            Ok(Response::new(Box::pin(tokio_stream::wrappers::ReceiverStream::new(rx))))
        }

        async fn talk_more_answer_one(&self, request: Request<Streaming<TalkRequest>>) -> Result<Response<TalkResponse>, Status> {
            let mut stream = request.into_inner();
            let mut collected_requests = Vec::new();
            while let Some(req_result) = stream.next().await {
                collected_requests.push(req_result.unwrap());
            }
            if let Some(tx) = &self.client_streaming_collector_tx {
                tx.send(collected_requests).await.expect("Failed to send collected client stream reqs");
            }
            Ok(Response::new(self.client_streaming_res.clone().unwrap_or_default()))
        }

        type TalkBidirectionalStream = Pin<Box<dyn Stream<Item = Result<TalkResponse, Status>> + Send + Sync + 'static>>;

        async fn talk_bidirectional(&self, request: Request<Streaming<TalkRequest>>) -> Result<Response<Self::TalkBidirectionalStream>, Status> {
            let mut client_stream = request.into_inner();
            let mut collected_requests = Vec::new();
            // Drain the client stream first (simplistic, real bidi might interleave)
            while let Some(req_result) = client_stream.next().await {
                 collected_requests.push(req_result.unwrap());
            }
            if let Some(tx) = &self.bidi_req_collector_tx {
                tx.send(collected_requests).await.expect("Failed to send collected bidi reqs");
            }

            let count = self.bidi_res_count;
            let (tx_response, rx_response) = mpsc::channel(count + 1); // Use count for channel size
            tokio::spawn(async move {
                for i in 0..count {
                    let response = TalkResponse {
                        status: 200,
                        results: vec![TalkResult {
                            kv: {
                                let mut map = HashMap::new();
                                map.insert("data".to_string(), format!("Mock Bidi Stream Msg {}", i+1));
                                map
                            },
                            ..Default::default()
                        }],
                    };
                    tx_response.send(Ok(response)).await.unwrap();
                }
            });
            Ok(Response::new(Box::pin(tokio_stream::wrappers::ReceiverStream::new(rx_response))))
        }
    }

    async fn run_mock_server(mock_service: MockLandingService, port: u16) -> (SocketAddr, oneshot::Sender<()>) {
        let addr: SocketAddr = format!("[::1]:{}", port).parse().unwrap();
        let (shutdown_tx, shutdown_rx) = oneshot::channel(); // For shutdown signal

        tokio::spawn(async move {
            Server::builder()
                .add_service(LandingServiceServer::new(mock_service))
                .serve_with_shutdown(addr, async { shutdown_rx.await.ok(); })
                .await
                .unwrap();
        });
        // Wait a bit for server to start, simplistic
        tokio::time::sleep(Duration::from_millis(100)).await; 
        (addr, shutdown_tx)
    }
    
    // Helper to build a real client connected to our mock server
    async fn build_test_client(server_addr: SocketAddr) -> LandingServiceClient<Channel> {
        // Temporarily override env vars for this client connection
        let original_backend = env::var("GRPC_HELLO_BACKEND").ok();
        let original_port = env::var("GRPC_HELLO_BACKEND_PORT").ok();
        let original_secure = env::var("GRPC_HELLO_SECURE").ok();

        env::set_var("GRPC_HELLO_BACKEND", server_addr.ip().to_string());
        env::set_var("GRPC_HELLO_BACKEND_PORT", server_addr.port().to_string());
        env::set_var("GRPC_HELLO_SECURE", "N"); // Connect insecurely to mock server

        let client = crate::common::conn::build_client().await;

        // Restore env vars
        original_backend.map_or_else(|| env::remove_var("GRPC_HELLO_BACKEND"), |v| env::set_var("GRPC_HELLO_BACKEND", v));
        original_port.map_or_else(|| env::remove_var("GRPC_HELLO_BACKEND_PORT"), |v| env::set_var("GRPC_HELLO_BACKEND_PORT", v));
        original_secure.map_or_else(|| env::remove_var("GRPC_HELLO_SECURE"), |v| env::set_var("GRPC_HELLO_SECURE", v));
        
        client
    }


    #[tokio::test]
    async fn test_client_talk_unary() {
        let (unary_req_tx, mut unary_req_rx) = mpsc::channel(1);
        let mock_service = MockLandingService {
            unary_req_tx: Some(unary_req_tx),
            unary_res: Some(TalkResponse { status: 200, results: vec![TalkResult {
                kv: {
                    let mut map = HashMap::new();
                    map.insert("data".to_string(), "Mock Unary OK".to_string());
                    map
                },
                ..Default::default()
            }]}),
            ..Default::default()
        };
        let (server_addr, shutdown_tx) = run_mock_server(mock_service, 50061).await; // Use a unique port
        let mut client = build_test_client(server_addr).await;

        // Call the actual client.rs's talk function
        super::talk(&mut client).await.expect("Client's talk function failed");

        let received_req = unary_req_rx.recv().await.unwrap();
        assert_eq!(received_req.data, "0"); // Default data from client's talk()
        assert_eq!(received_req.meta, "RUST");
        // print_response is called inside client's talk(), not easily assertable here
        shutdown_tx.send(()).unwrap(); // Shutdown server
    }

    #[tokio::test]
    async fn test_client_talk_one_answer_more() {
        let (server_streaming_req_tx, mut server_streaming_req_rx) = mpsc::channel(1);
        let mock_service = MockLandingService {
            server_streaming_req_tx: Some(server_streaming_req_tx),
            server_streaming_res_count: 2, // Mock server sends 2 messages
            ..Default::default()
        };
        let (server_addr, shutdown_tx) = run_mock_server(mock_service, 50062).await;
        let mut client = build_test_client(server_addr).await;

        super::talk_one_answer_more(&mut client).await.expect("Client's server streaming failed");
        
        let received_req = server_streaming_req_rx.recv().await.unwrap();
        assert_eq!(received_req.data, "0,1,2"); // Default data from client's talk_one_answer_more()
        // Output of print_response called inside client's function is not captured here.
        // Test primarily verifies client calls server and server stream is processed without error.
        shutdown_tx.send(()).unwrap(); // Shutdown server
    }

    #[tokio::test]
    async fn test_client_talk_more_answer_one() {
        let (client_streaming_collector_tx, mut client_streaming_collector_rx) = mpsc::channel(1);
        let mock_service = MockLandingService {
            client_streaming_collector_tx: Some(client_streaming_collector_tx),
            client_streaming_res: Some(TalkResponse { status: 200, results: vec![TalkResult {
                 kv: {
                    let mut map = HashMap::new();
                    map.insert("data".to_string(), "Mock ClientStream OK".to_string());
                    map
                },
                ..Default::default()
            }]}),
            ..Default::default()
        };
        let (server_addr, shutdown_tx) = run_mock_server(mock_service, 50063).await;
        let mut client = build_test_client(server_addr).await;

        super::talk_more_answer_one(&mut client).await.expect("Client's client streaming failed");

        let received_reqs = client_streaming_collector_rx.recv().await.unwrap();
        assert_eq!(received_reqs.len(), 3); // client.rs build_link_requests() sends 3
        assert_eq!(received_reqs[0].meta, "RUST");
        shutdown_tx.send(()).unwrap(); // Shutdown server
    }

    #[tokio::test]
    async fn test_client_talk_bidirectional() {
        let (bidi_req_collector_tx, mut bidi_req_collector_rx) = mpsc::channel(1);
        let mock_service = MockLandingService {
            bidi_req_collector_tx: Some(bidi_req_collector_tx),
            bidi_res_count: 3, // Mock server sends 3 messages back
            ..Default::default()
        };
        let (server_addr, shutdown_tx) = run_mock_server(mock_service, 50064).await;
        let mut client = build_test_client(server_addr).await;

        super::talk_bidirectional(&mut client).await.expect("Client's bidi streaming failed");

        let received_reqs = bidi_req_collector_rx.recv().await.unwrap();
        // client.rs talk_bidirectional sends 3 requests
        assert_eq!(received_reqs.len(), 3); 
        assert_eq!(received_reqs[0].meta, "RUST");
        shutdown_tx.send(()).unwrap(); // Shutdown server
    }
}
