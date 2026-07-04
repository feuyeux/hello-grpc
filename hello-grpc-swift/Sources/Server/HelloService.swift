import ArgumentParser
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import HelloCommon
import Logging
import NIOCore
import NIOPosix

final class HelloService: Hello_LandingService.ServiceProtocol, @unchecked Sendable {
    let logger = Logger(label: "HelloService")
    let backendConfig: (host: String, port: Int, useTLS: Bool)?
    let certBasePath: String
    
    // Lazy backend client - created on first use
    private var _backendClient: Hello_LandingService.ClientProtocol?
    private let backendClientLock = NSLock()
    
    init(backendConfig: (host: String, port: Int, useTLS: Bool)?, certBasePath: String) {
        self.backendConfig = backendConfig
        self.certBasePath = certBasePath
    }
    
    private func getBackendClient() throws -> Hello_LandingService.ClientProtocol? {
        guard let config = backendConfig else {
            return nil
        }
        
        // Thread-safe lazy initialization
        backendClientLock.lock()
        defer { backendClientLock.unlock() }
        
        if _backendClient == nil {
            logger.info("Initializing backend client connection to \(config.host):\(config.port)")
            
            let backendTransport: HTTP2ClientTransport.Posix

            // Client-side HTTP/2 keepalive for the proxy backend channel.
            let transportConfig: HTTP2ClientTransport.Posix.Config = .defaults { config in
                config.connection.keepalive = .init(
                    time: .seconds(10),
                    timeout: .seconds(1),
                    allowWithoutCalls: true
                )
            }
            
            if config.useTLS {
                logger.info("Using TLS for backend connection")
                let rootCertPath = "\(certBasePath)/full_chain.pem"
                
                backendTransport = try HTTP2ClientTransport.Posix(
                    target: .ipv4(host: config.host, port: config.port),
                    transportSecurity: .tls(
                        .init(
                            certificateChain: [],
                            privateKey: nil,
                            serverCertificateVerification: .noVerification,
                            trustRoots: .certificates([.file(path: rootCertPath, format: .pem)])
                        )
                    ),
                    config: transportConfig
                )
            } else {
                logger.info("Using plaintext for backend connection")
                backendTransport = try HTTP2ClientTransport.Posix(
                    target: .ipv4(host: config.host, port: config.port),
                    transportSecurity: .plaintext,
                    config: transportConfig
                )
            }
            
            let client = GRPCClient(transport: backendTransport)
            _backendClient = Hello_LandingService.Client(wrapping: client)
            logger.info("Backend client initialized successfully")
        }
        
        return _backendClient
    }

    // Unary RPC implementation
    func talk(
        request: GRPCCore.ServerRequest<Hello_TalkRequest>,
        context: GRPCCore.ServerContext
    ) async throws -> GRPCCore.ServerResponse<Hello_TalkResponse> {
        let message = request.message
        logger.info("[\(message.data)] talk request: data=\(message.data), meta=\(message.meta)")

        if let backendClient = try getBackendClient() {
            // Forward request to backend service
            let startTime = Date()
            logger.info("[\(message.data)] 开始调用后端服务: \(startTime)")
            let response = try await backendClient.talk(message, metadata: request.metadata)
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            logger.info("[\(message.data)] 后端服务调用完成: \(endTime), 耗时: \(elapsedTime)秒")
            return GRPCCore.ServerResponse(message: response, metadata: [:])
        }

        let reply: Hello_TalkResponse = .with {
            $0.status = 200
            $0.results = [buildResult(rid: message.data)]
        }
        return GRPCCore.ServerResponse(message: reply, metadata: [:])
    }

    // Server Streaming RPC implementation
    func talkOneAnswerMore(
        request: GRPCCore.ServerRequest<Hello_TalkRequest>,
        context: GRPCCore.ServerContext
    ) async throws -> GRPCCore.StreamingServerResponse<Hello_TalkResponse> {
        let message = request.message
        let requestId = UUID().uuidString
        logger.info("[\(requestId)] talkOneAnswerMore request: data=\(message.data), meta=\(message.meta)")

        if let backendClient = try getBackendClient() {
            let startTime = Date()
            logger.info("[\(requestId)] 开始调用后端服务 talkOneAnswerMore: \(startTime)")
            return GRPCCore.StreamingServerResponse<Hello_TalkResponse>(metadata: [:]) { [self] writer in
                let _ = try await backendClient.talkOneAnswerMore(message, metadata: request.metadata) { streamResponse in
                    self.logger.info("[\(requestId)] 开始处理 talkOneAnswerMore 流响应")
                    for try await responseMessage in streamResponse.messages {
                        try await writer.write(responseMessage)
                        self.logger.info("[\(requestId)] 已写入一条 talkOneAnswerMore 响应")
                    }
                    let endTime = Date()
                    let elapsedTime = endTime.timeIntervalSince(startTime)
                    self.logger.info("[\(requestId)] talkOneAnswerMore 流处理完成: 耗时: \(elapsedTime)秒")
                }
                self.logger.info("[\(requestId)] talkOneAnswerMore 请求已发送至后端")
                return [:]
            }
        }

        return GRPCCore.StreamingServerResponse<Hello_TalkResponse>(metadata: [:]) { [self] writer in
            let datas: [String] = message.data.components(separatedBy: ",")
            for d in datas {
                try await writer.write(
                    .with {
                        $0.status = 200
                        $0.results = [self.buildResult(rid: d)]
                    }
                )
                self.logger.info("[\(requestId)] talkOneAnswerMore sent response for data=\(d)")
            }
            return [:]
        }
    }

    // Client Streaming RPC implementation
    func talkMoreAnswerOne(
        request: GRPCCore.StreamingServerRequest<Hello_TalkRequest>,
        context: GRPCCore.ServerContext
    ) async throws -> GRPCCore.ServerResponse<Hello_TalkResponse> {
        let requestId = UUID().uuidString
        logger.info("[\(requestId)] 开始处理 talkMoreAnswerOne 请求")

        if let backendClient = try getBackendClient() {
            // Forward request to backend service
            let startTime = Date()
            logger.info("[\(requestId)] 开始调用后端服务 talkMoreAnswerOne: \(startTime)")
            let response = try await backendClient.talkMoreAnswerOne(
                metadata: request.metadata,
                requestProducer: { [self] writer in
                    for try await req in request.messages {
                        self.logger.info("[\(requestId)] 转发请求到后端: \(req.data)")
                        try await writer.write(req)
                    }
                    self.logger.info("[\(requestId)] 所有客户端请求已转发至后端")
                }
            )
            let endTime = Date()
            let elapsedTime = endTime.timeIntervalSince(startTime)
            logger.info("[\(requestId)] talkMoreAnswerOne 请求完成: 耗时: \(elapsedTime)秒")
            return GRPCCore.ServerResponse(message: response, metadata: [:])
        }

        var results: [Hello_TalkResult] = []
        for try await req in request.messages {
            logger.info("[\(requestId)] talkMoreAnswerOne received request: data=\(req.data), meta=\(req.meta)")
            results.append(buildResult(rid: req.data))
        }

        logger.info("[\(requestId)] talkMoreAnswerOne 处理完成, 返回结果")
        let reply: Hello_TalkResponse = .with {
            $0.status = 200
            $0.results = results
        }
        return GRPCCore.ServerResponse(message: reply, metadata: [:])
    }

    // Bidirectional Streaming RPC implementation
    func talkBidirectional(
        request: GRPCCore.StreamingServerRequest<Hello_TalkRequest>,
        context: GRPCCore.ServerContext
    ) async throws -> GRPCCore.StreamingServerResponse<Hello_TalkResponse> {
        let requestId = UUID().uuidString
        logger.info("[\(requestId)] 开始处理 talkBidirectional 请求")

        if let backendClient = try getBackendClient() {
            let startTime = Date()
            logger.info("[\(requestId)] 开始调用后端服务 talkBidirectional: \(startTime)")
            return GRPCCore.StreamingServerResponse<Hello_TalkResponse>(metadata: [:]) { [self] writer in
                try await backendClient.talkBidirectional(metadata: request.metadata) { backendWriter in
                    self.logger.info("[\(requestId)] 开始转发请求到后端服务")
                    for try await req in request.messages {
                        self.logger.info("[\(requestId)] 转发请求到后端: \(req.data)")
                        try await backendWriter.write(req)
                    }
                    self.logger.info("[\(requestId)] 完成所有客户端请求转发")
                } onResponse: { streamResponse in
                    self.logger.info("[\(requestId)] 开始处理后端服务响应")
                    for try await responseMessage in streamResponse.messages {
                        self.logger.info("[\(requestId)] 接收到后端响应")
                        try await writer.write(responseMessage)
                        self.logger.info("[\(requestId)] 已将响应写回客户端")
                    }
                    let endTime = Date()
                    let elapsedTime = endTime.timeIntervalSince(startTime)
                    self.logger.info("[\(requestId)] talkBidirectional 请求完成: 耗时: \(elapsedTime)秒")
                    return ()
                }
                self.logger.info("[\(requestId)] 已发送 talkBidirectional 请求到后端")
                return [:]
            }
        }

        return GRPCCore.StreamingServerResponse<Hello_TalkResponse>(metadata: [:]) { [self] writer in
            for try await req in request.messages {
                self.logger.info("[\(requestId)] talkBidirectional received: data=\(req.data), meta=\(req.meta)")
                let result = self.buildResult(rid: req.data)
                try await writer.write(
                    .with {
                        $0.status = 200
                        $0.results = [result]
                    }
                )
                self.logger.info("[\(requestId)] talkBidirectional sent response for data=\(req.data)")
            }
            return [:]
        }
    }

    // Helper method to build a result object based on the request index
    func buildResult(rid: String) -> Hello_TalkResult {
        let index = Int(rid) ?? 0
        var kv: [String: String] = [:]
        kv["id"] = ""
        kv["idx"] = rid
        let hello: String = Utils.helloList[index]
        kv["data"] = hello + "," + Utils.ansMap[hello]!
        kv["meta"] = "SWIFT"
        var result = Hello_TalkResult()
        let now = Date()
        let timeInterval: TimeInterval = now.timeIntervalSince1970
        result.id = Int64(timeInterval)
        result.type = .ok
        result.kv = kv
        return result
    }
}
