import Foundation
import GRPCCore
import HelloCommon
import Logging
import Testing

@testable import HelloServer
 
@Suite("HelloService Tests")
struct HelloServiceTests {
    @Test("HelloService.talk should forward requests to backend")
    func testTalkMethodTransparency() async throws {
        // Create a mock backend client that will record the request and return a predefined response
        let mockBackend = MockBackendClient()

        // Create the HelloService with our mock backend
        let helloService = HelloService(backendClient: mockBackend)

        // Create test request
        let testRequest = Hello_TalkRequest.with {
            $0.data = "test-input-data"
            $0.meta = "test-input-meta"
        }

        // For testing, let's create a simplified ServerContext
        let serviceDescriptor = GRPCCore.ServiceDescriptor(fullyQualifiedService: "test.Service")
        let descriptor = MethodDescriptor(service: serviceDescriptor, method: "talk")
        let mockContext = GRPCCore.ServerContext(
            descriptor: descriptor,
            remotePeer: "test-peer",
            localPeer: "local-peer",
            cancellation: GRPCCore.ServerContext.RPCCancellationHandle()
        )

        // Call the service method
        let response = try await helloService.talk(request: testRequest, context: mockContext)

        // Verify the request was passed through correctly to the backend
        let requestData = await mockBackend.getLastRequestData()
        let requestMeta = await mockBackend.getLastRequestMeta()
        #expect(requestData == testRequest.data)
        #expect(requestMeta == testRequest.meta)

        // Verify the response from the backend was returned without modification
        #expect(response.status == 200)
        #expect(response.results.count == 1)
        #expect(response.results[0].id == 12345)
        #expect(response.results[0].type == Hello_ResultType.ok)
        #expect(response.results[0].kv["id"] == "test-id")
        #expect(response.results[0].kv["data"] == "test-data")

        // Verify metadata received by the backend
        let backendReceivedMetadata = await mockBackend.storage.getLastTalkRequestMetadata()
        #expect(backendReceivedMetadata?.isEmpty == true, "Backend should have received empty metadata as HelloService does not propagate it by default.")
    }

    // Helper to create a ServerContext - can be shared by tests
    private func makeTestServerContext(methodName: String = "testMethod") -> GRPCCore.ServerContext {
        let serviceDescriptor = GRPCCore.ServiceDescriptor(fullyQualifiedService: "test.Service")
        let descriptor = MethodDescriptor(service: serviceDescriptor, method: methodName)
        return GRPCCore.ServerContext(
            descriptor: descriptor,
            remotePeer: "test-peer",
            localPeer: "local-peer",
            cancellation: GRPCCore.ServerContext.RPCCancellationHandle()
        )
    }

    // --- Non-Proxy Mode Tests ---

    @Test("NonProxy.talk - Unary call", arguments: [
        ("0", Utils.helloList[0], Utils.ansMap[Utils.helloList[0]]!),
        ("1", Utils.helloList[1], Utils.ansMap[Utils.helloList[1]]!)
    ])
    func testTalkNonProxy(dataIndexStr: String, expectedHello: String, expectedThanks: String) async throws {
        let helloService = HelloService(backendClient: nil) // Non-proxy mode
        let testRequest = Hello_TalkRequest.with {
            $0.data = dataIndexStr
            $0.meta = "TestClientNonProxy"
        }
        let context = makeTestServerContext(methodName: "talk")

        let response = try await helloService.talk(request: testRequest, context: context)

        #expect(response.status == 200)
        #expect(response.results.count == 1)
        let result = response.results[0]
        #expect(result.type == .ok)
        #expect(result.kv["idx"] == dataIndexStr)
        #expect(result.kv["meta"] == "SWIFT")
        #expect(result.kv["data"] == "\(expectedHello),\(expectedThanks)")
        #expect(result.id != 0) // Should have a timestamp
    }

    @Test("NonProxy.talkOneAnswerMore - Server Streaming")
    func testTalkOneAnswerMoreNonProxy() async throws {
        let helloService = HelloService(backendClient: nil)
        let testRequest = Hello_TalkRequest.with {
            $0.data = "0,2" // Requesting for index 0 and 2
            $0.meta = "TestClientServerStream"
        }
        
        // Prepare to collect responses
        var receivedResponses: [Hello_TalkResponse] = []
        
        // Create a simple RPCWriter that collects responses
        let (stream, continuation) = AsyncStream.makeStream(of: Hello_TalkResponse.self)
        let writer = GRPCCore.RPCWriter(wrapping: continuation)

        let context = makeTestServerContext(methodName: "talkOneAnswerMore")
        
        // Call the service method in a separate task as it might suspend
        Task {
            do {
                try await helloService.talkOneAnswerMore(request: testRequest, response: writer, context: context)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        for try await response in stream {
            receivedResponses.append(response)
        }

        #expect(receivedResponses.count == 2)

        // Check first response (for data "0")
        let resp1 = receivedResponses[0]
        #expect(resp1.status == 200)
        #expect(resp1.results.count == 1)
        let result1 = resp1.results[0]
        let expectedHello1 = Utils.helloList[0]
        let expectedThanks1 = Utils.ansMap[expectedHello1]!
        #expect(result1.kv["data"] == "\(expectedHello1),\(expectedThanks1)")
        #expect(result1.kv["idx"] == "0")
        #expect(result1.kv["meta"] == "SWIFT")

        // Check second response (for data "2")
        let resp2 = receivedResponses[1]
        #expect(resp2.status == 200)
        #expect(resp2.results.count == 1)
        let result2 = resp2.results[0]
        let expectedHello2 = Utils.helloList[2]
        let expectedThanks2 = Utils.ansMap[expectedHello2]!
        #expect(result2.kv["data"] == "\(expectedHello2),\(expectedThanks2)")
        #expect(result2.kv["idx"] == "2")
        #expect(result2.kv["meta"] == "SWIFT")
    }

    @Test("NonProxy.talkMoreAnswerOne - Client Streaming")
    func testTalkMoreAnswerOneNonProxy() async throws {
        let helloService = HelloService(backendClient: nil)
        let requestsData = [
            Hello_TalkRequest.with { $0.data = "0"; $0.meta = "ClientStream1"; },
            Hello_TalkRequest.with { $0.data = "3"; $0.meta = "ClientStream2"; },
        ]

        let (stream, continuation) = AsyncStream.makeStream(of: Hello_TalkRequest.self)
        Task { // Produce requests in a separate task
            for req in requestsData {
                continuation.yield(req)
            }
            continuation.finish()
        }
        let requestSequence = GRPCCore.RPCAsyncSequence(wrapping: stream)
        let context = makeTestServerContext(methodName: "talkMoreAnswerOne")

        let response = try await helloService.talkMoreAnswerOne(request: requestSequence, context: context)

        #expect(response.status == 200)
        #expect(response.results.count == 2)

        // Check first result (from data "0")
        let result1 = response.results[0]
        let expectedHello1 = Utils.helloList[0]
        let expectedThanks1 = Utils.ansMap[expectedHello1]!
        #expect(result1.kv["data"] == "\(expectedHello1),\(expectedThanks1)")
        #expect(result1.kv["idx"] == "0")

        // Check second result (from data "3")
        let result2 = response.results[1]
        let expectedHello2 = Utils.helloList[3]
        let expectedThanks2 = Utils.ansMap[expectedHello2]!
        #expect(result2.kv["data"] == "\(expectedHello2),\(expectedThanks2)")
        #expect(result2.kv["idx"] == "3")
    }

    @Test("NonProxy.talkBidirectional - Bidirectional Streaming")
    func testTalkBidirectionalNonProxy() async throws {
        let helloService = HelloService(backendClient: nil)
        let clientRequestsData = [
            Hello_TalkRequest.with { $0.data = "1"; $0.meta = "ClientBidi1"; },
            Hello_TalkRequest.with { $0.data = "4"; $0.meta = "ClientBidi2"; },
        ]

        // Client request stream
        let (clientReqStream, clientReqContinuation) = AsyncStream.makeStream(of: Hello_TalkRequest.self)
        Task {
            for req in clientRequestsData {
                clientReqContinuation.yield(req)
                try await Task.sleep(for: .milliseconds(10)) // Small delay
            }
            clientReqContinuation.finish()
        }
        let requestSequence = GRPCCore.RPCAsyncSequence(wrapping: clientReqStream)

        // Server response stream
        var receivedResponses: [Hello_TalkResponse] = []
        let (serverRespStream, serverRespContinuation) = AsyncStream.makeStream(of: Hello_TalkResponse.self)
        let writer = GRPCCore.RPCWriter(wrapping: serverRespContinuation)
        
        let context = makeTestServerContext(methodName: "talkBidirectional")

        // Call the service method in a task
        let serverTask = Task {
            do {
                try await helloService.talkBidirectional(request: requestSequence, response: writer, context: context)
                serverRespContinuation.finish()
            } catch {
                serverRespContinuation.finish(throwing: error)
            }
        }

        // Collect responses
        for try await response in serverRespStream {
            receivedResponses.append(response)
        }
        
        try await serverTask.value // Ensure server task completes and check for errors

        #expect(receivedResponses.count == 2)

        // Check first response (for data "1")
        let resp1 = receivedResponses[0]
        let result1 = resp1.results[0]
        let expectedHello1 = Utils.helloList[1]
        let expectedThanks1 = Utils.ansMap[expectedHello1]!
        #expect(result1.kv["data"] == "\(expectedHello1),\(expectedThanks1)")
        #expect(result1.kv["idx"] == "1")

        // Check second response (for data "4")
        let resp2 = receivedResponses[1]
        let result2 = resp2.results[0]
        let expectedHello2 = Utils.helloList[4]
        let expectedThanks2 = Utils.ansMap[expectedHello2]!
        #expect(result2.kv["data"] == "\(expectedHello2),\(expectedThanks2)")
        #expect(result2.kv["idx"] == "4")
    }

    // --- Proxy Mode Tests ---
    @Test("Proxy.talkOneAnswerMore - Server Streaming")
    func testTalkOneAnswerMoreProxy() async throws {
        let mockBackend = MockBackendClient()
        let expectedRequestData = "proxyServerStreamTest"
        let mockResponses = [
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data": "StreamMsg1"] }] },
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data": "StreamMsg2"] }] }
        ]
        await mockBackend.storage.setTalkOneAnswerMoreResponses(mockResponses)

        let helloService = HelloService(backendClient: mockBackend)
        let testRequest = Hello_TalkRequest.with {
            $0.data = expectedRequestData
            $0.meta = "TestClientProxyServerStream"
        }
        let context = makeTestServerContext(methodName: "talkOneAnswerMore")

        var receivedServiceResponses: [Hello_TalkResponse] = []
        let (stream, continuation) = AsyncStream.makeStream(of: Hello_TalkResponse.self)
        let writer = GRPCCore.RPCWriter(wrapping: continuation)

        // Call the service method in a task
        let serverTask = Task {
            do {
                try await helloService.talkOneAnswerMore(request: testRequest, response: writer, context: context)
                continuation.finish() 
            } catch {
                continuation.finish(throwing: error)
            }
        }

        for try await serviceResponse in stream {
            receivedServiceResponses.append(serviceResponse)
        }
        
        try await serverTask.value 

        let backendReceivedRequest = await mockBackend.storage.getLastTalkOneAnswerMoreRequest()
        #expect(backendReceivedRequest?.data == expectedRequestData)
        let backendReceivedMetadata = await mockBackend.storage.getLastTalkOneAnswerMoreRequestMetadata()
        #expect(backendReceivedMetadata?.isEmpty == true, "Backend should have received empty metadata for talkOneAnswerMore.")

        #expect(receivedServiceResponses.count == mockResponses.count)
        for i in 0..<mockResponses.count {
            #expect(receivedServiceResponses[i].results[0].kv["data"] == mockResponses[i].results[0].kv["data"])
        }
    }

    @Test("Proxy.talkMoreAnswerOne - Client Streaming")
    func testTalkMoreAnswerOneProxy() async throws {
        let mockBackend = MockBackendClient()
        let expectedResponseFromBackend = Hello_TalkResponse.with {
            $0.status = 200
            $0.results = [Hello_TalkResult.with { $0.kv = ["data": "ClientStreamProxy ACK"] }]
        }
        await mockBackend.storage.setTalkMoreAnswerOneResponse(expectedResponseFromBackend)

        let helloService = HelloService(backendClient: mockBackend)
        let context = makeTestServerContext(methodName: "talkMoreAnswerOne")

        let clientRequestsData = [
            Hello_TalkRequest.with { $0.data = "CSP1"; $0.meta = "ClientStreamProxy1"; },
            Hello_TalkRequest.with { $0.data = "CSP2"; $0.meta = "ClientStreamProxy2"; },
        ]

        let (clientReqStream, clientReqContinuation) = AsyncStream.makeStream(of: Hello_TalkRequest.self)
        Task {
            for req in clientRequestsData { clientReqContinuation.yield(req) }
            clientReqContinuation.finish()
        }
        let requestSequence = GRPCCore.RPCAsyncSequence(wrapping: clientReqStream)

        let serviceResponse = try await helloService.talkMoreAnswerOne(request: requestSequence, context: context)

        let backendReceivedRequests = await mockBackend.storage.getLastTalkMoreAnswerOneRequests()
        #expect(backendReceivedRequests?.count == clientRequestsData.count)
        if let backendRequests = backendReceivedRequests { 
            for i in 0..<clientRequestsData.count { #expect(backendRequests[i].data == clientRequestsData[i].data) }
        }
        let backendReceivedMetadata = await mockBackend.storage.getLastTalkMoreAnswerOneRequestMetadata()
        #expect(backendReceivedMetadata?.isEmpty == true, "Backend should have received empty metadata for talkMoreAnswerOne.")

        #expect(serviceResponse.results[0].kv["data"] == expectedResponseFromBackend.results[0].kv["data"])
    }

    @Test("Proxy.talkBidirectional - Bidirectional Streaming")
    func testTalkBidirectionalProxy() async throws {
        let mockBackend = MockBackendClient()
        let clientRequestsData = [
            Hello_TalkRequest.with { $0.data = "BidiProxy1"; $0.meta = "ClientBidiProxy1"; },
            Hello_TalkRequest.with { $0.data = "BidiProxy2"; $0.meta = "ClientBidiProxy2"; },
        ]
        let backendResponsesData = [
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data": "BidiStreamProxyMsg1"] }] },
            Hello_TalkResponse.with { $0.status = 200; $0.results = [Hello_TalkResult.with { $0.kv = ["data": "BidiStreamProxyMsg2"] }] },
        ]
        await mockBackend.storage.setTalkBidirectionalResponses(backendResponsesData)

        let helloService = HelloService(backendClient: mockBackend)
        let context = makeTestServerContext(methodName: "talkBidirectional")

        let (clientReqStream, clientReqContinuation) = AsyncStream.makeStream(of: Hello_TalkRequest.self)
        Task {
            for req in clientRequestsData {
                clientReqContinuation.yield(req)
                try await Task.sleep(for: .milliseconds(10))
            }
            clientReqContinuation.finish()
        }
        let requestSequence = GRPCCore.RPCAsyncSequence(wrapping: clientReqStream)

        var receivedServiceResponses: [Hello_TalkResponse] = []
        let (serverRespStream, serverRespContinuation) = AsyncStream.makeStream(of: Hello_TalkResponse.self)
        let writer = GRPCCore.RPCWriter(wrapping: serverRespContinuation)

        let serverTask = Task {
            do {
                try await helloService.talkBidirectional(request: requestSequence, response: writer, context: context)
                serverRespContinuation.finish()
            } catch { serverRespContinuation.finish(throwing: error) }
        }

        for try await serviceResponse in serverRespStream { receivedServiceResponses.append(serviceResponse) }
        try await serverTask.value 

        let backendReceivedRequests = await mockBackend.storage.getLastTalkBidirectionalRequests()
        #expect(backendReceivedRequests?.count == clientRequestsData.count)
        if let backendRequests = backendReceivedRequests { 
             for i in 0..<clientRequestsData.count { #expect(backendRequests[i].data == clientRequestsData[i].data) }
        }
        let backendReceivedMetadata = await mockBackend.storage.getLastTalkBidirectionalRequestMetadata()
        #expect(backendReceivedMetadata?.isEmpty == true, "Backend should have received empty metadata for talkBidirectional.")

        #expect(receivedServiceResponses.count == backendResponsesData.count)
        for i in 0..<backendResponsesData.count {
            #expect(receivedServiceResponses[i].results[0].kv["data"] == backendResponsesData[i].results[0].kv["data"])
        }
    }
}


// Mock implementation of the backend client
final class MockBackendClient: Hello_LandingService.ClientProtocol {
    public actor Storage { 
        var lastRequestData: String?
        var lastRequestMeta: String?
        var lastTalkRequestMetadata: GRPCCore.Metadata?
        
        var lastTalkOneAnswerMoreRequest: Hello_TalkRequest?
        var lastTalkOneAnswerMoreRequestMetadata: GRPCCore.Metadata?
        var talkOneAnswerMoreResponses: [Hello_TalkResponse] = []

        var lastTalkMoreAnswerOneRequests: [Hello_TalkRequest]? 
        var lastTalkMoreAnswerOneRequestMetadata: GRPCCore.Metadata?
        var talkMoreAnswerOneResponse: Hello_TalkResponse?      

        var lastTalkBidirectionalRequests: [Hello_TalkRequest]? 
        var lastTalkBidirectionalRequestMetadata: GRPCCore.Metadata?
        var talkBidirectionalResponses: [Hello_TalkResponse] = [] 

        func setRequest(data: String, meta: String) { lastRequestData = data; lastRequestMeta = meta }
        func getRequestData() -> String? { lastRequestData }
        func getRequestMeta() -> String? { lastRequestMeta }
        
        func setLastTalkRequestMetadata(_ metadata: GRPCCore.Metadata) { lastTalkRequestMetadata = metadata }
        func getLastTalkRequestMetadata() -> GRPCCore.Metadata? { lastTalkRequestMetadata }
        
        func setTalkOneAnswerMoreRequest(_ request: Hello_TalkRequest) { lastTalkOneAnswerMoreRequest = request }
        func getLastTalkOneAnswerMoreRequest() -> Hello_TalkRequest? { lastTalkOneAnswerMoreRequest }
        func setTalkOneAnswerMoreRequestMetadata(_ metadata: GRPCCore.Metadata) { lastTalkOneAnswerMoreRequestMetadata = metadata }
        func getLastTalkOneAnswerMoreRequestMetadata() -> GRPCCore.Metadata? { lastTalkOneAnswerMoreRequestMetadata }
        func setTalkOneAnswerMoreResponses(_ responses: [Hello_TalkResponse]) { talkOneAnswerMoreResponses = responses }
        func getTalkOneAnswerMoreResponses() -> [Hello_TalkResponse] { talkOneAnswerMoreResponses }

        func setLastTalkMoreAnswerOneRequests(_ requests: [Hello_TalkRequest]) { lastTalkMoreAnswerOneRequests = requests }
        func getLastTalkMoreAnswerOneRequests() -> [Hello_TalkRequest]? { lastTalkMoreAnswerOneRequests }
        func setLastTalkMoreAnswerOneRequestMetadata(_ metadata: GRPCCore.Metadata) { lastTalkMoreAnswerOneRequestMetadata = metadata }
        func getLastTalkMoreAnswerOneRequestMetadata() -> GRPCCore.Metadata? { lastTalkMoreAnswerOneRequestMetadata }
        func setTalkMoreAnswerOneResponse(_ response: Hello_TalkResponse) { talkMoreAnswerOneResponse = response }
        func getTalkMoreAnswerOneResponse() -> Hello_TalkResponse? { talkMoreAnswerOneResponse }

        func setLastTalkBidirectionalRequests(_ requests: [Hello_TalkRequest]) { lastTalkBidirectionalRequests = requests }
        func getLastTalkBidirectionalRequests() -> [Hello_TalkRequest]? { lastTalkBidirectionalRequests }
        func setLastTalkBidirectionalRequestMetadata(_ metadata: GRPCCore.Metadata) { lastTalkBidirectionalRequestMetadata = metadata }
        func getLastTalkBidirectionalRequestMetadata() -> GRPCCore.Metadata? { lastTalkBidirectionalRequestMetadata }
        func setTalkBidirectionalResponses(_ responses: [Hello_TalkResponse]) { talkBidirectionalResponses = responses }
        func getTalkBidirectionalResponses() -> [Hello_TalkResponse] { talkBidirectionalResponses }
    }

    public let storage = Storage() 

    func getLastRequestData() async -> String? { await storage.getRequestData() }
    func getLastRequestMeta() async -> String? { await storage.getRequestMeta() }

    func talk<Result: Sendable>(
        _ message: Hello_TalkRequest,
        metadata: GRPCCore.Metadata = [:], 
        options _: GRPCCore.CallOptions = .defaults,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Hello_TalkResponse>) async throws -> Result = { response in
            try response.message as! Result
        }
    ) async throws -> Result {
        await storage.setRequest(data: message.data, meta: message.meta)
        await storage.setLastTalkRequestMetadata(metadata) 
        let mockResponse = Hello_TalkResponse.with {
            $0.status = 200
            $0.results = [Hello_TalkResult.with {
                $0.id = 12345; $0.type = .ok; $0.kv = ["id": "test-id", "data": "test-data"]
            }]
        }
        let clientResponse = GRPCCore.ClientResponse<Hello_TalkResponse>(message: mockResponse, metadata: [:])
        return try await handleResponse(clientResponse)
    }

    func talk<Result: Sendable>(
        request clientRequest: GRPCCore.ClientRequest<Hello_TalkRequest>, 
        serializer _: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer _: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        try await talk( clientRequest.message, metadata: clientRequest.metadata, options: options, onResponse: handleResponse)
    }

    func talkOneAnswerMore<Result: Sendable>(
        request clientRequest: GRPCCore.ClientRequest<Hello_TalkRequest>,
        serializer _: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer _: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options _: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        await storage.setTalkOneAnswerMoreRequest(clientRequest.message)
        await storage.setLastTalkOneAnswerMoreRequestMetadata(clientRequest.metadata)
        let responses = await storage.getTalkOneAnswerMoreResponses()
        let (stream, continuation) = AsyncStream.makeStream(of: Hello_TalkResponse.self)
        Task { 
            for response in responses { continuation.yield(response) }
            continuation.finish()
        }
        let responseStream = GRPCCore.ClientResponseStream(accepted: true, metadata: [:], messages: GRPCCore.RPCAsyncSequence(wrapping: stream))
        return try await handleResponse(responseStream)
    }

    func talkMoreAnswerOne<Result: Sendable>(
        request clientRequest: GRPCCore.StreamingClientRequest<Hello_TalkRequest>,
        serializer _: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer _: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options _: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        var collectedRequests: [Hello_TalkRequest] = []
        var iterator = clientRequest.messages.makeAsyncIterator()
        while let message = try await iterator.next() { collectedRequests.append(message) }
        await storage.setLastTalkMoreAnswerOneRequests(collectedRequests)
        await storage.setLastTalkMoreAnswerOneRequestMetadata(clientRequest.metadata)
        
        let response = await storage.getTalkMoreAnswerOneResponse() ?? Hello_TalkResponse()
        let clientResponse = GRPCCore.ClientResponse<Hello_TalkResponse>(message: response, metadata: [:])
        return try await handleResponse(clientResponse)
    }

    func talkBidirectional<Result: Sendable>(
        request clientRequest: GRPCCore.StreamingClientRequest<Hello_TalkRequest>,
        serializer _: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer _: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options _: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        var collectedRequests: [Hello_TalkRequest] = []
        var iterator = clientRequest.messages.makeAsyncIterator()
        while let message = try await iterator.next() { collectedRequests.append(message) }
        await storage.setLastTalkBidirectionalRequests(collectedRequests)
        await storage.setLastTalkBidirectionalRequestMetadata(clientRequest.metadata)

        let responses = await storage.getTalkBidirectionalResponses()
        let (stream, continuation) = AsyncStream.makeStream(of: Hello_TalkResponse.self)
        Task {
            for response in responses { continuation.yield(response) }
            continuation.finish()
        }
        let responseStream = GRPCCore.ClientResponseStream(accepted: true, metadata: [:], messages: GRPCCore.RPCAsyncSequence(wrapping: stream))
        return try await handleResponse(responseStream)
    }
    
    func talkBidirectional<Result: Sendable>(
        serializer: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onRequest: @escaping (GRPCCore.RPCWriter<Hello_TalkRequest>) async throws -> Void,
        onResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        fatalError("Simplified talkBidirectional not fully implemented for advanced mock scenarios in this test setup")
    }
}
