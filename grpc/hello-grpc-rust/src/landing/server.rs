use std::collections::HashMap;
use std::env;
use std::pin::Pin;

use chrono::prelude::*;
use env_logger::Env;
use futures::{Stream, StreamExt};
use futures::stream;
use log::{debug, error, info};
use tokio::sync::mpsc;
use tonic::{Request, Response, Status, Streaming, transport::Server};
use tonic::metadata::{Ascii, KeyAndValueRef, MetadataKey, MetadataMap};
use tonic::transport::Channel;
use uuid::Uuid;

use landing::{ResultType, TalkRequest, TalkResponse, TalkResult};
use landing::landing_service_client::LandingServiceClient;
use landing::landing_service_server::{LandingService, LandingServiceServer};

static HELLOS: [&'static str; 6] = [
    "Hello",
    "Bonjour",
    "Hola",
    "こんにちは",
    "Ciao",
    "안녕하세요",
];

static TRACING_KEYS: [&'static str; 7] = [
    "x-request-id",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-ot-span-context",
];

pub mod landing {
    tonic::include_proto!("org.feuyeux.grpc");
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let default = Env::default().default_filter_or("info");
    env_logger::Builder::from_env(default).format_timestamp_millis().init();

    let address = format!("0.0.0.0:{}", match env::var("GRPC_HELLO_PORT") {
        Ok(val) => val,
        Err(_e) => "9996".to_string()
    }).parse().unwrap();

    let backend = match env::var("GRPC_HELLO_BACKEND") {
        Ok(val) => val,
        Err(_e) => String::default()
    };

    if !backend.is_empty() {
        let next_address = format!("http://{}:{}", backend, match env::var("GRPC_HELLO_BACKEND_PORT") {
            Ok(val) => val,
            Err(_e) => "8001".to_string()
        });
        info!("Next server is:{}", next_address);
        let client = LandingServiceClient::connect(next_address).await?;
        info!("ProtoServer listening on {}", address);
        Server::builder()
            .add_service(LandingServiceServer::new(ProtoServer { backend, client: Some(client) }))
            .serve(address)
            .await?;
        Ok(())
    } else {
        info!("ProtoServer listening on {}", address);
        Server::builder()
            .add_service(LandingServiceServer::new(ProtoServer { backend, client: None }))
            .serve(address)
            .await?;
        Ok(())
    }
}

pub struct ProtoServer {
    backend: String,
    client: Option<LandingServiceClient<Channel>>,
}

#[tonic::async_trait]
impl LandingService for ProtoServer {
    type TalkOneAnswerMoreStream = Pin<Box<dyn Stream<Item=Result<TalkResponse, Status>> + Send + Sync + 'static>>;
    type TalkBidirectionalStream = Pin<Box<dyn Stream<Item=Result<TalkResponse, Status>> + Send + Sync + 'static>>;

    async fn talk(
        &self,
        mut request: Request<TalkRequest>)
        -> Result<Response<TalkResponse>, Status> {
        let talk_request: &TalkRequest = request.get_ref();
        let data: &String = &talk_request.data;
        let meta: &String = &talk_request.meta;
        info!("TALK REQUEST: data={:?},meta={:?}", data, meta);
        print_metadata(request.metadata());

        if !self.backend.is_empty() {
            match &self.client {
                Some(client) => {
                    //TODO request and header is same...
                    let _ = propaganda_headers(&mut request);
                    let mut c = client.clone();
                    let response: &Response<TalkResponse> = &c.talk(request).await?;
                    let talk_response = response.get_ref();
                    info!("Talk={:?}", talk_response);
                    Ok(Response::new(talk_response.clone()))
                }
                None => {
                    error!("Cannot find next client");
                    Ok(Response::new(TalkResponse::default()))
                }
            }
        } else {
            let result = build_result(data.clone());
            let response = TalkResponse {
                status: 200,
                results: vec![result],
            };
            Ok(Response::new(response))
        }
    }

    async fn talk_one_answer_more(
        &self, request: Request<TalkRequest>)
        -> Result<Response<Self::TalkOneAnswerMoreStream>, Status> {
        let (tx, rx) = mpsc::channel(4);
        if !self.backend.is_empty() {
            match &self.client {
                Some(client) => {
                    let mut c = client.clone();
                    let stream = &mut c.talk_one_answer_more(request).await?.into_inner();
                    while let Some(talk_response) = stream.message().await? {
                        let talk_response = talk_response.clone();
                        tx.send(Ok(talk_response)).await.unwrap();
                    }
                }
                None => {
                    error!("Cannot find next client");
                }
            }
        } else {
            tokio::spawn(async move {
                let talk_request: &TalkRequest = request.get_ref();
                let data: &String = &talk_request.data;
                let meta: &String = &talk_request.meta;
                info!("TalkOneAnswerMore REQUEST: data={:?},meta={:?}", data, meta);
                print_metadata(request.metadata());
                let datas = data.split(",");
                for data in datas {
                    let result = build_result(data.to_string());
                    let response = TalkResponse {
                        status: 200,
                        results: vec![result],
                    };
                    tx.send(Ok(response)).await.unwrap();
                }
            });
        }
        Ok(Response::new(Box::pin(
            tokio_stream::wrappers::ReceiverStream::new(rx),
        )))
    }

    async fn talk_more_answer_one(
        &self, request: Request<tonic::Streaming<TalkRequest>>)
        -> Result<Response<TalkResponse>, Status> {
        info!("TalkMoreAnswerOne REQUEST: ");
        print_metadata(request.metadata());
        let mut inbound_streaming = request.into_inner();
        if !self.backend.is_empty() {
            let mut requests = vec![];
            let response = match &self.client {
                Some(client) => {
                    let mut c: LandingServiceClient<Channel> = client.clone();
                    // -> TODO outbound
                    while let Some(talk_request) = inbound_streaming.next().await {
                        let talk_request = talk_request?;
                        requests.push(talk_request);
                    }
                    let outbound = Request::new(stream::iter(requests));
                    // <- TODO
                    let talk_response = &c.talk_more_answer_one(outbound).await?.into_inner();
                    talk_response.clone()
                }
                None => {
                    error!("Cannot find next client");
                    TalkResponse::default()
                }
            };

            Ok(Response::new(response))
        } else {
            let mut rs = vec![];
            while let Some(talk_request) = inbound_streaming.next().await {
                let talk_request = talk_request?;
                let data: &String = &talk_request.data;
                let meta: &String = &talk_request.meta;
                info!("data={:?},meta={:?}", data, meta);
                let result = build_result(data.to_string());
                rs.push(result);
            }
            let response = TalkResponse {
                status: 200,
                results: rs,
            };
            Ok(Response::new(response))
        }
    }

    async fn talk_bidirectional(
        &self, request: Request<Streaming<TalkRequest>>)
        -> Result<Response<Self::TalkBidirectionalStream>, Status> {
        info!("TalkBidirectional REQUEST:");
        print_metadata(request.metadata());
        let mut stream = request.into_inner();

        if !self.backend.is_empty() {
            match &self.client {
                Some(client) => {
                    let (tx, rx) = mpsc::channel(4);
                    let mut c: LandingServiceClient<Channel> = client.clone();
                    let mut requests = vec![];
                    while let Some(talk_request) = stream.next().await {
                        let talk_request = talk_request?;
                        requests.push(talk_request);
                    }
                    let outbound = Request::new(stream::iter(requests));
                    let stream = &mut c.talk_bidirectional(outbound).await?.into_inner();
                    while let Some(talk_response) = stream.message().await? {
                        let talk_response = talk_response.clone();
                        tx.send(Ok(talk_response)).await.unwrap();
                    }
                    Ok(Response::new(Box::pin(
                        tokio_stream::wrappers::ReceiverStream::new(rx),
                    )))
                }
                None => {
                    error!("Cannot find next client");
                    let inbound_streaming = async_stream::try_stream! {
                        yield TalkResponse::default()
                    };
                    Ok(Response::new(
                        Box::pin(inbound_streaming) as Self::TalkBidirectionalStream
                    ))
                }
            }
        } else {
            let output = async_stream::try_stream! {
                while let Some(talk_request) = stream.next().await {
                    let talk_request = talk_request?;
                    let data: &String = &talk_request.data;
                    let meta: &String = &talk_request.meta;
                    info!("data={:?},meta={:?}", data, meta);
                    let result = build_result(data.to_string());
                    let response = TalkResponse {
                        status: 200,
                        results: vec![result],
                    };
                    yield response;
                }
            };
            Ok(Response::new(
                Box::pin(output) as Self::TalkBidirectionalStream
            ))
        }
    }
}

fn build_result(id: String) -> TalkResult {
    let mut map: HashMap<String, String> = HashMap::new();
    let index = id.parse::<usize>().unwrap();
    let uuid = Uuid::new_v4();
    map.insert("id".to_string(), uuid.to_string());
    map.insert("idx".to_string(), id);
    map.insert("data".to_string(), HELLOS[index].to_string());
    map.insert("meta".to_string(), "RUST".to_string());
    let ok = ResultType::Ok as i32;
    let result = TalkResult {
        id: Utc::now().timestamp_millis(),
        r#type: ok,
        kv: map,
    };
    return result;
}

fn print_metadata(header: &MetadataMap) {
    for kv in header.iter() {
        match kv {
            KeyAndValueRef::Ascii(ref k, ref v) => info!("H: {:?}: {:?}", k, v),
            KeyAndValueRef::Binary(ref k, ref v) => info!("H: {:?}: {:?}", k, v),
        }
    }
}

fn propaganda_headers(request: &mut Request<TalkRequest>) -> MetadataMap {
    request.metadata_mut().clear();
    let mut map = MetadataMap::new();
    let headers = request.metadata_mut();
    for key in &TRACING_KEYS {
        let key: MetadataKey<Ascii> = MetadataKey::from_static(key);
        match headers.get(&key) {
            Some(v) => {
                map.insert(&key, v.clone());
            }
            None => {
                debug!("key doesn't exist in header");
            }
        }
    }
    map
}