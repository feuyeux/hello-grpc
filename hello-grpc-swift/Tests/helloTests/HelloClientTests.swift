import Testing
import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2 // For ClientConnection and Server
import HelloCommon // Common types like Hello_TalkRequest etc.
import Logging // For passing a logger to client funcs
import NIOCore // For MultiThreadedEventLoopGroup

// @testable import HelloClient // Static functions in an executable's main file are not easily importable.
                                 // We need to copy/paste or refactor them.
                                 // For now, we will COPY the static client methods into this test file
                                 // or a test-local helper struct for direct invocation.

// --- Mock Service Implementation (Server-Side) ---
@GRPCService
class MockLandingServiceForClientTesting: Hello_LandingService.SimpleServiceProtocol {
    // Use an actor for safe mutable state
    actor State {
        var lastUnaryRequest: Hello_TalkRequest?
        var unaryResponse: Hello_TalkResponse?

        var lastServerStreamingRequest: Hello_TalkRequest?
        var serverStreamingResponses: [Hello_TalkResponse]?

        var collectedClientStreamingRequests: [Hello_TalkRequest]?
        var clientStreamingResponse: Hello_TalkResponse?
        
        var collectedBidiRequests: [Hello_TalkRequest]?
        var bidiResponses: [Hello_TalkResponse]?

        // Methods to set expectations and get received data
        func recordUnaryRequest(_ req: Hello_TalkRequest) { lastUnaryRequest = req }
        func setUnaryResponse(_ res: Hello_TalkResponse) { unaryResponse = res }
        
        func recordServerStreamingRequest(_ req: Hello_TalkRequest) { lastServerStreamingRequest = req }
        func setServerStreamingResponses(_ res: [Hello_TalkResponse]) { serverStreamingResponses = res }

        func recordClientStreamingRequests(_ reqs: [Hello_TalkRequest]) { collectedClientStreamingRequests = reqs }
        func setClientStreamingResponse(_ res: Hello_TalkResponse) { clientStreamingResponse = res }
        
        func recordBidiRequests(_ reqs: [Hello_TalkRequest]) { collectedBidiRequests = reqs }
        func setBidiResponses(_ res: [Hello_TalkResponse]) { bidiResponses = res }
    }

    let state: State

    init() {
        self.state = State()
    }

    func talk(request: Hello_TalkRequest, context: ServerContext) async throws -> Hello_TalkResponse {
        await state.recordUnaryRequest(request)
        guard let response = await state.unaryResponse else {
            throw GRPCStatus(code: .notFound, message: "Unary response not configured for mock")
        }
        return response
    }

    func talkOneAnswerMore(request: Hello_TalkRequest, response writer: RPCWriter<Hello_TalkResponse>, context: ServerContext) async throws {
        await state.recordServerStreamingRequest(request)
        if let responses = await state.serverStreamingResponses {
            for res in responses {
                try await writer.write(res)
            }
        } else {
             throw GRPCStatus(code: .notFound, message: "Server streaming responses not configured for mock")
        }
    }

    func talkMoreAnswerOne(request: RPCAsyncSequence<Hello_TalkRequest, any Error>, context: ServerContext) async throws -> Hello_TalkResponse {
        var collected: [Hello_TalkRequest] = []
        for try await req in request {
            collected.append(req)
        }
        await state.recordClientStreamingRequests(collected)
        guard let response = await state.clientStreamingResponse else {
            throw GRPCStatus(code: .notFound, message: "Client streaming response not configured for mock")
        }
        return response
    }

    func talkBidirectional(request: RPCAsyncSequence<Hello_TalkRequest, any Error>, response writer: RPCWriter<Hello_TalkResponse>, context: ServerContext) async throws {
        var collected: [Hello_TalkRequest] = []
        for try await req in request {
            collected.append(req)
        }
        await state.recordBidiRequests(collected)
        
        if let responsesToStream = await state.bidiResponses {
            for res in responsesToStream {
                try await writer.write(res)
            }
        } else {
            // If no specific responses, just finish. Or throw error if that's desired.
        }
    }
}

// --- Test Suite ---
@Suite("HelloClient Logic Tests")
struct HelloClientTests {
    var server: Server?
    var client: Hello_LandingService.Client?
    var mockServiceState: MockLandingServiceForClientTesting.State?
    var eventLoopGroup: MultiThreadedEventLoopGroup?

    // --- COPIED Client Functions from hello-grpc-swift/Sources/Client/HelloClient.swift ---
    static func clientTalk(client: Hello_LandingService.ClientProtocol, logger: Logger) async {
        logger.info("→ talk:")
        let requestMessage = Hello_TalkRequest.with {
            $0.data = "0"
            $0.meta = "SWIFT"
        }
        let metadata: Metadata = ["request-id": format!("unary-{}", UUID().uuidString)]
        
        do {
            let response = try await client.talk(requestMessage, metadata: metadata)
            logger.info("Talk Response \(response.status) \(formatResponse(response))")
        } catch {
            logger.error("RPC failed: \(error)")
        }
    }

    static func clientTalkOneAnswerMore(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        logger.info("→ talkOneAnswerMore:")
        let requestMessage = Hello_TalkRequest.with {
            $0.data = "0,1,2"
            $0.meta = "SWIFT"
        }
        let metadata: Metadata = ["request-id": format!("ss-{}", UUID().uuidString)]
        let clientRequest = GRPCCore.ClientRequest.SingleMessage(message: requestMessage, metadata: metadata)

        _ = try await client.talkOneAnswerMore(request: clientRequest) { responseStream in
            var resultCount = 1
            for try await resp in responseStream.messages {
                logger.info(
                    "TalkOneAnswerMore Response[\(resultCount)] \(resp.status) \(formatResponse(resp))"
                )
                resultCount += 1
            }
        }
    }

    static func clientTalkMoreAnswerOne(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        logger.info("→ talkMoreAnswerOne")
        let rid = Int.random(in: 0 ..< 6)
        let requests: [Hello_TalkRequest] = [
            .with { $0.data = String(rid); $0.meta = "SWIFT"; },
            .with { $0.data = "1"; $0.meta = "SWIFT"; },
            .with { $0.data = "2"; $0.meta = "SWIFT"; },
        ]
        
        let (stream, continuation) = AsyncStream.makeStream(of: Hello_TalkRequest.self)
        Task {
            for req in requests {
                continuation.yield(req)
            }
            continuation.finish()
        }
        
        let streamingRequest = GRPCCore.StreamingClientRequest(
            metadata: ["request-id": format!("cs-{}", UUID().uuidString)],
            messages: GRPCCore.RPCAsyncSequence(wrapping: stream)
        )
        
        let response = try await client.talkMoreAnswerOne(request: streamingRequest) { clientResponse in
             return clientResponse.message
        }
        logger.info("TalkMoreAnswerOne Response \(response.status) \(formatResponse(response))")
    }

    static func clientTalkBidirectional(
        client: Hello_LandingService.ClientProtocol,
        logger: Logger
    ) async throws {
        logger.info("→ talkBidirectional")
        let requests: [Hello_TalkRequest] = [
            .with { $0.data = "0"; $0.meta = "SWIFT"; },
            .with { $0.data = "1"; $0.meta = "SWIFT"; },
            .with { $0.data = "2"; $0.meta = "SWIFT"; },
        ]

        let (requestStreamContinuation, requestStream) = GRPCCore.RPCWriter.makeStream(of: Hello_TalkRequest.self)
        Task {
            for request in requests {
                try await Task.sleep(nanoseconds: UInt64.random(in: UInt64(1e7) ... UInt64(1e8)))
                try! await requestStreamContinuation.send(request)
            }
            requestStreamContinuation.finish()
        }
        
        let streamingRequest = GRPCCore.StreamingClientRequest(
            metadata: ["request-id": format!("bidi-{}", UUID().uuidString)],
            messages: GRPCCore.RPCAsyncSequence(wrapping: requestStream)
        )

        _ = try await client.talkBidirectional(request: streamingRequest) { responseStream in
            var resultCount = 1
            for try await resp in responseStream.messages {
                 logger.info("TalkBidirectional Response[\(resultCount)] \(resp.status) \(formatResponse(resp))")
                 resultCount += 1
            }
        }
    }
    
    static func formatResponse(_ response: Hello_TalkResponse) -> String {
        var parts: [String] = []
        if !response.results.isEmpty {
            for result in response.results {
                var resultParts: [String] = []
                resultParts.append("id: \(result.id)")
                var kvPairs: [String] = []
                for (key, value) in result.kv {
                    kvPairs.append("\(key): \"\(value)\"")
                }
                resultParts.append("kv: {" + kvPairs.joined(separator: ", ") + "}")
                parts.append("{" + resultParts.joined(separator: ", ") + "}")
            }
            return "[" + parts.joined(separator: ", ") + "]"
        } else {
            return "[]"
        }
    }

    // --- Test Cases ---
    @Test("Test Client Unary Call (talk)")
    mutating func testClientUnaryTalk() async throws { 
        let mockService = MockLandingServiceForClientTesting()
        let expectedData = "MockUnaryOK for talk"
        let expectedResponse = Hello_TalkResponse.with { 
            $0.status = 200
            $0.results = [Hello_TalkResult.with { 
                $0.kv = ["data": expectedData, "idx": "0", "meta": "MOCK"]
                $0.id = 123
                $0.type = .ok
            }] 
        }
        await mockService.state.setUnaryResponse(expectedResponse)
        
        self.mockServiceState = mockService.state

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = try await Server(
            transport: .inProcess(eventLoopGroup: eventLoopGroup!),
            services: [mockService]
        )
        self.server = server
        
        let clientConnection = ClientConnection(transport: .inProcess(server: server))
        self.client = Hello_LandingService.Client(wrapping: clientConnection)

        let testLogger = Logger(label: "testClientUnaryTalk")
        testLogger.logLevel = .debug 
        
        await Self.clientTalk(client: self.client!, logger: testLogger) 
        
        let lastReq = await self.mockServiceState!.lastUnaryRequest
        #expect(lastReq?.data == "0")
        #expect(lastReq?.meta == "SWIFT")
        
        try await clientConnection.close().get()
        try await self.server!.stop().get()
        try await self.eventLoopGroup!.shutdownGracefully()
    }

    @Test("Test Client Server Streaming Call (talkOneAnswerMore)")
    mutating func testClientServerStreaming() async throws {
        let mockService = MockLandingServiceForClientTesting()
        let expectedResponses = [
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data":"Stream1"]}] },
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data":"Stream2"]}] }
        ]
        await mockService.state.setServerStreamingResponses(expectedResponses)
        
        self.mockServiceState = mockService.state

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = try await Server(
            transport: .inProcess(eventLoopGroup: eventLoopGroup!),
            services: [mockService]
        )
        self.server = server
        
        let clientConnection = ClientConnection(transport: .inProcess(server: server))
        self.client = Hello_LandingService.Client(wrapping: clientConnection)
        let testLogger = Logger(label: "testClientServerStreaming")
        testLogger.logLevel = .debug

        try await Self.clientTalkOneAnswerMore(client: self.client!, logger: testLogger)

        let lastReq = await self.mockServiceState!.lastServerStreamingRequest
        #expect(lastReq?.data == "0,1,2") 
        
        try await clientConnection.close().get()
        try await self.server!.stop().get()
        try await self.eventLoopGroup!.shutdownGracefully()
    }

    @Test("Test Client Client Streaming Call (talkMoreAnswerOne)")
    mutating func testClientClientStreaming() async throws {
        let mockService = MockLandingServiceForClientTesting()
        let expectedResponse = Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data":"ClientStreamACK"]}] }
        await mockService.state.setClientStreamingResponse(expectedResponse)
        
        self.mockServiceState = mockService.state

        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = try await Server(
            transport: .inProcess(eventLoopGroup: eventLoopGroup!),
            services: [mockService]
        )
        self.server = server
        
        let clientConnection = ClientConnection(transport: .inProcess(server: server))
        self.client = Hello_LandingService.Client(wrapping: clientConnection)
        let testLogger = Logger(label: "testClientClientStreaming")
        testLogger.logLevel = .debug

        try await Self.clientTalkMoreAnswerOne(client: self.client!, logger: testLogger)

        let collectedReqs = await self.mockServiceState!.collectedClientStreamingRequests
        #expect(collectedReqs != nil)
        #expect(collectedReqs?.count == 3) 
        // First request's data is random, so we only check meta for it.
        #expect(collectedReqs?[0].meta == "SWIFT")
        #expect(collectedReqs?[1].data == "1")
        #expect(collectedReqs?[1].meta == "SWIFT")
        #expect(collectedReqs?[2].data == "2")
        #expect(collectedReqs?[2].meta == "SWIFT")
        
        try await clientConnection.close().get()
        try await self.server!.stop().get()
        try await self.eventLoopGroup!.shutdownGracefully()
    }

    @Test("Test Client Bidirectional Streaming Call (talkBidirectional)")
    mutating func testClientBidirectionalStreaming() async throws {
        let mockService = MockLandingServiceForClientTesting()
        let serverResponses = [
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data":"BidiResponse1"]}] },
        ]
        await mockService.state.setBidiResponses(serverResponses)
        
        self.mockServiceState = mockService.state
        
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = try await Server(
            transport: .inProcess(eventLoopGroup: eventLoopGroup!),
            services: [mockService]
        )
        self.server = server
        
        let clientConnection = ClientConnection(transport: .inProcess(server: server))
        self.client = Hello_LandingService.Client(wrapping: clientConnection)
        let testLogger = Logger(label: "testClientBidiStreaming")
        testLogger.logLevel = .debug

        try await Self.clientTalkBidirectional(client: self.client!, logger: testLogger)

        let collectedReqs = await self.mockServiceState!.collectedBidiRequests
        #expect(collectedReqs != nil)
        #expect(collectedReqs?.count == 3) 
        #expect(collectedReqs?[0].data == "0")
        #expect(collectedReqs?[0].meta == "SWIFT")
        #expect(collectedReqs?[1].data == "1")
        #expect(collectedReqs?[2].data == "2")
        
        try await clientConnection.close().get()
        try await self.server!.stop().get()
        try await self.eventLoopGroup!.shutdownGracefully()
    }
}
