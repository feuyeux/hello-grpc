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
    }
}

// Mock implementation of the backend client
// Need to use final class for Sendable conformance and mark as @unchecked Sendable
final class MockBackendClient: Hello_LandingService.ClientProtocol {
    // Use actor for thread safety
    private actor Storage {
        var lastRequestData: String?
        var lastRequestMeta: String?

        func setRequest(data: String, meta: String) {
            lastRequestData = data
            lastRequestMeta = meta
        }

        func getRequestData() -> String? {
            lastRequestData
        }

        func getRequestMeta() -> String? {
            lastRequestMeta
        }
    }

    private let storage = Storage()

    func getLastRequestData() async -> String? {
        await storage.getRequestData()
    }

    func getLastRequestMeta() async -> String? {
        await storage.getRequestMeta()
    }

    // Implement the core protocol method that our test will use
    func talk<Result: Sendable>(
        _ message: Hello_TalkRequest,
        metadata _: GRPCCore.Metadata = [:],
        options _: GRPCCore.CallOptions = .defaults,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Hello_TalkResponse>) async throws -> Result = { response in
            try response.message as! Result
        }
    ) async throws -> Result {
        // Record the request parameters
        await storage.setRequest(data: message.data, meta: message.meta)

        // Create a mock response
        let mockResponse = Hello_TalkResponse.with {
            $0.status = 200
            $0.results = [
                Hello_TalkResult.with {
                    $0.id = 12345
                    $0.type = .ok
                    $0.kv = ["id": "test-id", "data": "test-data"]
                },
            ]
        }

        // Create a client response from our mock data
        // Using the correct constructor format for GRPCCore.ClientResponse
        let clientResponse = GRPCCore.ClientResponse<Hello_TalkResponse>(
            message: mockResponse,
            metadata: [:]
        )

        // Call the handler with our mock response
        return try await handleResponse(clientResponse)
    }

    // Implement the required protocol method with the low-level signature
    func talk<Result: Sendable>(
        request: GRPCCore.ClientRequest<Hello_TalkRequest>,
        serializer _: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer _: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        // Simply delegate to our simplified implementation
        try await talk(
            request.message,
            metadata: request.metadata,
            options: options,
            onResponse: handleResponse
        )
    }

    // Simplified stubs for other required protocol methods
    func talkOneAnswerMore<Result: Sendable>(
        request: GRPCCore.ClientRequest<Hello_TalkRequest>,
        serializer: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        fatalError("Not implemented for this test")
    }

    // Simplified stubs for the remaining protocol methods
    func talkMoreAnswerOne<Result: Sendable>(
        request: GRPCCore.StreamingClientRequest<Hello_TalkRequest>,
        serializer: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onResponse: @Sendable @escaping (GRPCCore.ClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        fatalError("Not implemented for this test")
    }

    func talkBidirectional<Result: Sendable>(
        request: GRPCCore.StreamingClientRequest<Hello_TalkRequest>,
        serializer: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        fatalError("Not implemented for this test")
    }
    
    // Keep the previous implementation for backward compatibility with other tests
    func talkBidirectional<Result: Sendable>(
        serializer: some GRPCCore.MessageSerializer<Hello_TalkRequest>,
        deserializer: some GRPCCore.MessageDeserializer<Hello_TalkResponse>,
        options: GRPCCore.CallOptions,
        onRequest: @escaping (GRPCCore.RPCWriter<Hello_TalkRequest>) async throws -> Void,
        onResponse: @Sendable @escaping (GRPCCore.StreamingClientResponse<Hello_TalkResponse>) async throws -> Result
    ) async throws -> Result {
        fatalError("Not implemented for this test")
    }
}
