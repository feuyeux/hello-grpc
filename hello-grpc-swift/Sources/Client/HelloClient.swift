/// gRPC Client implementation for the Landing service (Swift).
///
/// This client demonstrates all four gRPC communication patterns:
/// 1. Unary RPC
/// 2. Server streaming RPC
/// 3. Client streaming RPC
/// 4. Bidirectional streaming RPC
///
/// The implementation follows standardized patterns for error handling,
/// logging, and graceful shutdown.

import ArgumentParser
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import HelloCommon
import Logging
import NIOCore
import NIOSSL

// Configuration constants
private let retryAttempts = 3
private let retryDelaySeconds: UInt64 = 2
private let iterationCount = 3
private let requestDelayMs: UInt64 = 200
private let sendDelayMs: UInt64 = 2
private let requestTimeoutSeconds: UInt64 = 5
private let defaultBatchSize = 5

struct HelloClient: AsyncParsableCommand {
    private var shutdownRequested = false
    
    func run() async throws {
        let logger = Logger(label: "HelloClient")
        setupSignalHandling()
        
        logger.info("Starting gRPC client [version: \(getVersion())]")
        
        // Retry logic for connection
        for attempt in 1...retryAttempts {
            if shutdownRequested {
                logger.info("Client shutting down, aborting connection attempts")
                return
            }
            
            logger.info("Connection attempt \(attempt)/\(retryAttempts)")
            
            do {
                let transport = try await createTransport(logger: logger)
                
                try await withGRPCClient(transport: transport) { client in
                    let serviceClient: Hello_LandingService.Client<HTTP2ClientTransport.Posix> =
                        Hello_LandingService.Client(wrapping: client)
                    
                    let success = await runGrpcCalls(
                        client: serviceClient,
                        logger: logger,
                        delayMs: requestDelayMs,
                        iterations: iterationCount
                    )
                    
                    if success || shutdownRequested {
                        return
                    }
                }
            } catch {
                logger.error("Connection attempt \(attempt) failed: \(error)")
                if attempt < retryAttempts && !shutdownRequested {
                    logger.info("Retrying in \(retryDelaySeconds) seconds...")
                    try await Task.sleep(nanoseconds: retryDelaySeconds * 1_000_000_000)
                }
            }
        }
        
        if shutdownRequested {
            logger.info("Client execution was cancelled")
        } else {
            logger.info("Client execution completed successfully")
        }
    }
    
    /// Set up signal handling for graceful shutdown
    private func setupSignalHandling() {
        signal(SIGINT) { _ in
            print("Received shutdown signal, cancelling operations")
        }
        
        signal(SIGTERM) { _ in
            print("Received SIGTERM signal, cancelling operations")
        }
    }
    
    /// Create and configure the gRPC transport
    private func createTransport(logger: Logger) async throws -> HTTP2ClientTransport.Posix {
        let conn = HelloConn()
        let connectTo = conn.host ?? "127.0.0.1"
        let useTLS = ProcessInfo.processInfo.environment["GRPC_HELLO_SECURE"] == "Y"
        
        logger.info("Connecting to \(connectTo):\(conn.port ?? 9996)")
        logger.info("TLS Mode: \(useTLS ? "Enabled" : "Disabled")")
        
        if useTLS {
            let certBasePath = getCertBasePath()
            let rootCertPath = "\(certBasePath)/full_chain.pem"
            
            logger.info("Using certificates from: \(certBasePath)")
            
            if FileManager.default.fileExists(atPath: rootCertPath) {
                logger.info("Loading root certificate: \(rootCertPath)")
                
                return try HTTP2ClientTransport.Posix(
                    target: .ipv4(host: connectTo, port: conn.port ?? 9996),
                    transportSecurity: .tls(
                        .init(
                            certificateChain: [],
                            privateKey: nil,
                            serverCertificateVerification: .noVerification,
                            trustRoots: .certificates([.file(path: rootCertPath, format: .pem)])
                        )
                    )
                )
            } else {
                logger.warning("Root certificate not found, falling back to plaintext")
            }
        }
        
        logger.info("Using plaintext connection")
        return try HTTP2ClientTransport.Posix(
            target: .ipv4(host: connectTo, port: conn.port ?? 9996),
            transportSecurity: .plaintext
        )
    }
    
    /// Run all gRPC call patterns multiple times
    private func runGrpcCalls(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger,
        delayMs: UInt64,
        iterations: Int
    ) async -> Bool {
        for iteration in 1...iterations {
            if shutdownRequested {
                return false
            }
            
            logger.info("====== Starting iteration \(iteration)/\(iterations) ======")
            
            do {
                // 1. Unary RPC
                logger.info("----- Executing unary RPC -----")
                try await executeUnaryCall(client: client, logger: logger)
                
                // 2. Server streaming RPC
                logger.info("----- Executing server streaming RPC -----")
                try await executeServerStreamingCall(client: client, logger: logger)
                
                // 3. Client streaming RPC
                logger.info("----- Executing client streaming RPC -----")
                let response = try await executeClientStreamingCall(client: client, logger: logger)
                logResponse(response, logger: logger)
                
                // 4. Bidirectional streaming RPC
                logger.info("----- Executing bidirectional streaming RPC -----")
                try await executeBidirectionalStreamingCall(client: client, logger: logger)
                
                if iteration < iterations && !shutdownRequested {
                    logger.info("Waiting \(delayMs)ms before next iteration...")
                    try await Task.sleep(nanoseconds: delayMs * 1_000_000)
                }
            } catch {
                logger.error("Error in iteration \(iteration): \(error)")
                return false
            }
        }
        
        logger.info("All gRPC calls completed successfully")
        return true
    }
    
    /// Execute unary RPC call
    private func executeUnaryCall(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        let requestId = "unary-\(Date().timeIntervalSince1970)"
        
        let request: Hello_TalkRequest = .with {
            $0.data = "0"
            $0.meta = "SWIFT"
        }
        
        let metadata: Metadata = [
            "request-id": requestId,
            "client": "swift-client"
        ]
        
        logger.info("Sending unary request: data=\(request.data), meta=\(request.meta)")
        let startTime = Date()
        
        do {
            let response = try await client.talk(request, metadata: metadata)
            let duration = Date().timeIntervalSince(startTime) * 1000
            logger.info("Unary call successful in \(Int(duration))ms")
            logResponse(response, logger: logger)
        } catch {
            logError(error, requestId: requestId, method: "Talk", logger: logger)
            throw error
        }
    }
    
    /// Execute server streaming RPC call
    private func executeServerStreamingCall(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        let requestId = "server-stream-\(Date().timeIntervalSince1970)"
        
        let request: Hello_TalkRequest = .with {
            $0.data = "0,1,2"
            $0.meta = "SWIFT"
        }
        
        let metadata: Metadata = [
            "request-id": requestId,
            "client": "swift-client"
        ]
        
        logger.info("Starting server streaming with request: data=\(request.data), meta=\(request.meta)")
        let startTime = Date()
        
        do {
            var responseCount = 0
            try await client.talkOneAnswerMore(request, metadata: metadata) { response in
                for try await resp in response.messages {
                    if shutdownRequested {
                        logger.info("Server streaming cancelled")
                        return
                    }
                    responseCount += 1
                    logger.info("Received server streaming response #\(responseCount):")
                    logResponse(resp, logger: logger)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime) * 1000
            logger.info("Server streaming completed: received \(responseCount) responses in \(Int(duration))ms")
        } catch {
            logError(error, requestId: requestId, method: "TalkOneAnswerMore", logger: logger)
            throw error
        }
    }
    
    /// Execute client streaming RPC call
    private func executeClientStreamingCall(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws -> Hello_TalkResponse {
        let requestId = "client-stream-\(Date().timeIntervalSince1970)"
        let requests = buildLinkRequests()
        
        logger.info("Starting client streaming with \(requests.count) requests")
        let startTime = Date()
        
        do {
            let response = try await client.talkMoreAnswerOne { writer in
                var requestCount = 0
                for request in requests {
                    if shutdownRequested {
                        logger.info("Client streaming cancelled")
                        return
                    }
                    requestCount += 1
                    logger.info("Sending client streaming request #\(requestCount): data=\(request.data), meta=\(request.meta)")
                    try await writer.write(request)
                    try await Task.sleep(nanoseconds: sendDelayMs * 1_000_000)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime) * 1000
            logger.info("Client streaming completed: sent \(requests.count) requests in \(Int(duration))ms")
            return response
        } catch {
            logError(error, requestId: requestId, method: "TalkMoreAnswerOne", logger: logger)
            throw error
        }
    }
    
    /// Execute bidirectional streaming RPC call
    private func executeBidirectionalStreamingCall(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        let requestId = "bidirectional-\(Date().timeIntervalSince1970)"
        let requests = buildLinkRequests()
        
        logger.info("Starting bidirectional streaming with \(requests.count) requests")
        let startTime = Date()
        
        do {
            var responseCount = 0
            try await client.talkBidirectional { writer in
                var requestCount = 0
                for request in requests {
                    if shutdownRequested {
                        logger.info("Bidirectional streaming cancelled")
                        return
                    }
                    requestCount += 1
                    logger.info("Sending bidirectional streaming request #\(requestCount): data=\(request.data), meta=\(request.meta)")
                    try await writer.write(request)
                    try await Task.sleep(nanoseconds: sendDelayMs * 1_000_000)
                }
            } onResponse: { responses in
                for try await response in responses.messages {
                    if shutdownRequested {
                        logger.info("Bidirectional streaming cancelled")
                        return
                    }
                    responseCount += 1
                    logger.info("Received bidirectional streaming response #\(responseCount):")
                    logResponse(response, logger: logger)
                }
            }
            
            let duration = Date().timeIntervalSince(startTime) * 1000
            logger.info("Bidirectional streaming completed in \(Int(duration))ms")
        } catch {
            logError(error, requestId: requestId, method: "TalkBidirectional", logger: logger)
            throw error
        }
    }
    
    /// Build a list of link requests for testing streaming RPCs
    private func buildLinkRequests() -> [Hello_TalkRequest] {
        return (0..<defaultBatchSize).map { _ in
            .with {
                $0.data = String(Int.random(in: 0..<6))
                $0.meta = "SWIFT"
            }
        }
    }
    
    /// Log response details
    private func logResponse(_ response: Hello_TalkResponse, logger: Logger) {
        logger.info("Response status: \(response.status), results: \(response.results.count)")
        
        for (index, result) in response.results.enumerated() {
            let meta = result.kv["meta"] ?? ""
            let id = result.kv["id"] ?? ""
            let idx = result.kv["idx"] ?? ""
            let data = result.kv["data"] ?? ""
            
            logger.info("  Result #\(index + 1): id=\(result.id), type=\(result.type), meta=\(meta), id=\(id), idx=\(idx), data=\(data)")
        }
    }
    
    /// Log error with context
    private func logError(_ error: Error, requestId: String, method: String, logger: Logger) {
        logger.error("Request failed - request_id: \(requestId), method: \(method), error: \(error)")
    }
    
    /// Get the certificate base path from environment or default location
    private func getCertBasePath() -> String {
        if let path = ProcessInfo.processInfo.environment["CERT_BASE_PATH"] {
            return path
        }
        
        #if os(macOS)
            return "/var/hello_grpc/client_certs"
        #elseif os(Windows)
            return "D:\\garden\\var\\hello_grpc\\client_certs"
        #else
            return "/var/hello_grpc/client_certs"
        #endif
    }
    
    /// Get version information
    private func getVersion() -> String {
        return "grpc.version=1.0.0" // Placeholder
    }
}

@main
extension HelloClient {}
