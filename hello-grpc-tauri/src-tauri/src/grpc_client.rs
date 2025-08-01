use crate::proto::hello::{
    landing_service_client::LandingServiceClient, TalkRequest, TalkResponse,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::Duration;
use thiserror::Error;
use tokio::sync::{mpsc, Mutex};
use tokio::time::timeout;
use tonic::transport::{Channel, ClientTlsConfig, Endpoint};
use tonic::{Request, Status, Streaming};

#[derive(Error, Debug)]
pub enum GrpcError {
    #[error("Connection error: {0}")]
    ConnectionError(#[from] tonic::transport::Error),
    
    #[error("gRPC call error: {0}")]
    GrpcCallError(#[from] tonic::Status),
    
    #[error("Timeout error: {0}")]
    TimeoutError(String),
    
    #[error("Configuration error: {0}")]
    ConfigError(String),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    
    #[error("Channel error: {0}")]
    ChannelError(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionSettings {
    pub server: String,
    pub port: u16,
    pub use_tls: bool,
    pub timeout_seconds: u64,
}

impl Default for ConnectionSettings {
    fn default() -> Self {
        Self {
            server: "localhost".to_string(),
            port: 9996,
            use_tls: false,
            timeout_seconds: 30,
        }
    }
}

impl ConnectionSettings {
    pub fn validate(&self) -> Result<(), GrpcError> {
        if self.server.is_empty() {
            return Err(GrpcError::ConfigError("Server address cannot be empty".to_string()));
        }
        if self.port == 0 {
            return Err(GrpcError::ConfigError("Port must be greater than 0".to_string()));
        }
        if self.timeout_seconds == 0 {
            return Err(GrpcError::ConfigError("Timeout must be greater than 0".to_string()));
        }
        Ok(())
    }

    pub fn get_endpoint_url(&self) -> String {
        let protocol = if self.use_tls { "https" } else { "http" };
        format!("{}://{}:{}", protocol, self.server, self.port)
    }
}

pub struct GrpcClient {
    client: Option<LandingServiceClient<Channel>>,
    pub settings: ConnectionSettings,
    is_connected: bool,
}

impl GrpcClient {
    pub fn new(settings: ConnectionSettings) -> Self {
        Self {
            client: None,
            settings,
            is_connected: false,
        }
    }

    pub async fn connect(&mut self) -> Result<(), GrpcError> {
        self.settings.validate()?;
        
        let endpoint_url = self.settings.get_endpoint_url();
        let mut endpoint = Endpoint::from_shared(endpoint_url)?
            .timeout(Duration::from_secs(self.settings.timeout_seconds));

        if self.settings.use_tls {
            let tls_config = ClientTlsConfig::new()
                .domain_name(&self.settings.server);
            endpoint = endpoint.tls_config(tls_config)?;
        }

        let channel = endpoint.connect().await?;
        self.client = Some(LandingServiceClient::new(channel));
        self.is_connected = true;
        
        Ok(())
    }

    pub fn is_connected(&self) -> bool {
        self.is_connected && self.client.is_some()
    }

    #[cfg(test)]
    pub fn set_connected_for_test(&mut self, connected: bool) {
        self.is_connected = connected;
    }

    pub async fn disconnect(&mut self) {
        self.client = None;
        self.is_connected = false;
    }

    pub fn update_settings(&mut self, settings: ConnectionSettings) {
        self.settings = settings;
        // Force reconnection with new settings
        self.is_connected = false;
        self.client = None;
    }

    async fn ensure_connected(&mut self) -> Result<(), GrpcError> {
        if !self.is_connected() {
            self.connect().await?;
        }
        Ok(())
    }

    pub async fn unary_call(&mut self, request: TalkRequest) -> Result<TalkResponse, GrpcError> {
        self.ensure_connected().await?;
        
        let client = self.client.as_mut()
            .ok_or_else(|| GrpcError::ConfigError("Client not connected".to_string()))?;

        let request = Request::new(request);
        let response = timeout(
            Duration::from_secs(self.settings.timeout_seconds),
            client.talk(request)
        ).await
        .map_err(|_| GrpcError::TimeoutError("Unary call timed out".to_string()))?;

        Ok(response?.into_inner())
    }

    pub async fn server_streaming_call(
        &mut self,
        request: TalkRequest,
    ) -> Result<Streaming<TalkResponse>, GrpcError> {
        self.ensure_connected().await?;
        
        let client = self.client.as_mut()
            .ok_or_else(|| GrpcError::ConfigError("Client not connected".to_string()))?;

        let request = Request::new(request);
        let response = timeout(
            Duration::from_secs(self.settings.timeout_seconds),
            client.talk_one_answer_more(request)
        ).await
        .map_err(|_| GrpcError::TimeoutError("Server streaming call timed out".to_string()))?;

        Ok(response?.into_inner())
    }

    pub async fn client_streaming_call(&mut self) -> Result<(mpsc::Sender<TalkRequest>, tokio::task::JoinHandle<Result<TalkResponse, GrpcError>>), GrpcError> {
        self.ensure_connected().await?;
        
        let client = self.client.as_mut()
            .ok_or_else(|| GrpcError::ConfigError("Client not connected".to_string()))?;

        let (tx, rx) = mpsc::channel(32);
        let (request_tx, request_rx) = mpsc::channel(32);
        
        // Convert mpsc receiver to stream
        let request_stream = tokio_stream::wrappers::ReceiverStream::new(request_rx);
        let request = Request::new(request_stream);
        
        let mut client_clone = client.clone();
        let timeout_duration = Duration::from_secs(self.settings.timeout_seconds);
        
        let handle = tokio::spawn(async move {
            let response = timeout(
                timeout_duration,
                client_clone.talk_more_answer_one(request)
            ).await
            .map_err(|_| GrpcError::TimeoutError("Client streaming call timed out".to_string()))?;
            
            response.map(|r| r.into_inner()).map_err(GrpcError::from)
        });

        // Forward messages from tx to request_tx
        let request_tx_clone = request_tx.clone();
        tokio::spawn(async move {
            let mut rx = rx;
            while let Some(msg) = rx.recv().await {
                if request_tx_clone.send(msg).await.is_err() {
                    break;
                }
            }
        });

        Ok((tx, handle))
    }

    pub async fn bidirectional_streaming_call(&mut self) -> Result<(mpsc::Sender<TalkRequest>, mpsc::Receiver<Result<TalkResponse, Status>>), GrpcError> {
        self.ensure_connected().await?;
        
        let client = self.client.as_mut()
            .ok_or_else(|| GrpcError::ConfigError("Client not connected".to_string()))?;

        let (request_tx, request_rx) = mpsc::channel(32);
        let (response_tx, response_rx) = mpsc::channel(32);
        
        // Convert mpsc receiver to stream
        let request_stream = tokio_stream::wrappers::ReceiverStream::new(request_rx);
        let request = Request::new(request_stream);
        
        let mut client_clone = client.clone();
        let timeout_duration = Duration::from_secs(self.settings.timeout_seconds);
        
        tokio::spawn(async move {
            let result = timeout(
                timeout_duration,
                client_clone.talk_bidirectional(request)
            ).await;
            
            match result {
                Ok(Ok(response)) => {
                    let mut stream = response.into_inner();
                    while let Ok(Some(msg)) = stream.message().await {
                        if response_tx.send(Ok(msg)).await.is_err() {
                            break;
                        }
                    }
                }
                Ok(Err(status)) => {
                    let _ = response_tx.send(Err(status)).await;
                }
                Err(_) => {
                    let _ = response_tx.send(Err(Status::deadline_exceeded("Bidirectional streaming call timed out"))).await;
                }
            }
        });

        Ok((request_tx, response_rx))
    }
}

// Thread-safe wrapper for GrpcClient
pub type SharedGrpcClient = Arc<Mutex<GrpcClient>>;

pub fn create_shared_client(settings: ConnectionSettings) -> SharedGrpcClient {
    Arc::new(Mutex::new(GrpcClient::new(settings)))
}