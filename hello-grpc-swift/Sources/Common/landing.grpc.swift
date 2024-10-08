//
// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the protocol buffer compiler.
// Source: landing.proto
//
import GRPC
import NIO
import NIOConcurrencyHelpers
import SwiftProtobuf


/// Usage: instantiate `Hello_LandingServiceClient`, then call methods of this protocol to make API calls.
public protocol Hello_LandingServiceClientProtocol: GRPCClient {
  var serviceName: String { get }
  var interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? { get }

  func talk(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Hello_TalkRequest, Hello_TalkResponse>

  func talkOneAnswerMore(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions?,
    handler: @escaping (Hello_TalkResponse) -> Void
  ) -> ServerStreamingCall<Hello_TalkRequest, Hello_TalkResponse>

  func talkMoreAnswerOne(
    callOptions: CallOptions?
  ) -> ClientStreamingCall<Hello_TalkRequest, Hello_TalkResponse>

  func talkBidirectional(
    callOptions: CallOptions?,
    handler: @escaping (Hello_TalkResponse) -> Void
  ) -> BidirectionalStreamingCall<Hello_TalkRequest, Hello_TalkResponse>
}

extension Hello_LandingServiceClientProtocol {
  public var serviceName: String {
    return "hello.LandingService"
  }

  ///Unary RPC
  ///
  /// - Parameters:
  ///   - request: Request to send to Talk.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func talk(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeUnaryCall(
      path: Hello_LandingServiceClientMetadata.Methods.talk.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkInterceptors() ?? []
    )
  }

  ///Server streaming RPC
  ///
  /// - Parameters:
  ///   - request: Request to send to TalkOneAnswerMore.
  ///   - callOptions: Call options.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ServerStreamingCall` with futures for the metadata and status.
  public func talkOneAnswerMore(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions? = nil,
    handler: @escaping (Hello_TalkResponse) -> Void
  ) -> ServerStreamingCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeServerStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkOneAnswerMore.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? [],
      handler: handler
    )
  }

  ///Client streaming RPC with random & sleep
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata, status and response.
  public func talkMoreAnswerOne(
    callOptions: CallOptions? = nil
  ) -> ClientStreamingCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeClientStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  ///Bidirectional streaming RPC
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata and status.
  public func talkBidirectional(
    callOptions: CallOptions? = nil,
    handler: @escaping (Hello_TalkResponse) -> Void
  ) -> BidirectionalStreamingCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeBidirectionalStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? [],
      handler: handler
    )
  }
}

@available(*, deprecated)
extension Hello_LandingServiceClient: @unchecked Sendable {}

@available(*, deprecated, renamed: "Hello_LandingServiceNIOClient")
public final class Hello_LandingServiceClient: Hello_LandingServiceClientProtocol {
  private let lock = Lock()
  private var _defaultCallOptions: CallOptions
  private var _interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol?
  public let channel: GRPCChannel
  public var defaultCallOptions: CallOptions {
    get { self.lock.withLock { return self._defaultCallOptions } }
    set { self.lock.withLockVoid { self._defaultCallOptions = newValue } }
  }
  public var interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? {
    get { self.lock.withLock { return self._interceptors } }
    set { self.lock.withLockVoid { self._interceptors = newValue } }
  }

  /// Creates a client for the hello.LandingService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self._defaultCallOptions = defaultCallOptions
    self._interceptors = interceptors
  }
}

public struct Hello_LandingServiceNIOClient: Hello_LandingServiceClientProtocol {
  public var channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol?

  /// Creates a client for the hello.LandingService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public protocol Hello_LandingServiceAsyncClientProtocol: GRPCClient {
  static var serviceDescriptor: GRPCServiceDescriptor { get }
  var interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? { get }

  func makeTalkCall(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions?
  ) -> GRPCAsyncUnaryCall<Hello_TalkRequest, Hello_TalkResponse>

  func makeTalkOneAnswerMoreCall(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions?
  ) -> GRPCAsyncServerStreamingCall<Hello_TalkRequest, Hello_TalkResponse>

  func makeTalkMoreAnswerOneCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncClientStreamingCall<Hello_TalkRequest, Hello_TalkResponse>

  func makeTalkBidirectionalCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncBidirectionalStreamingCall<Hello_TalkRequest, Hello_TalkResponse>
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
extension Hello_LandingServiceAsyncClientProtocol {
  public static var serviceDescriptor: GRPCServiceDescriptor {
    return Hello_LandingServiceClientMetadata.serviceDescriptor
  }

  public var interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? {
    return nil
  }

  public func makeTalkCall(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncUnaryCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeAsyncUnaryCall(
      path: Hello_LandingServiceClientMetadata.Methods.talk.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkInterceptors() ?? []
    )
  }

  public func makeTalkOneAnswerMoreCall(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncServerStreamingCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeAsyncServerStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkOneAnswerMore.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? []
    )
  }

  public func makeTalkMoreAnswerOneCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncClientStreamingCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeAsyncClientStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  public func makeTalkBidirectionalCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncBidirectionalStreamingCall<Hello_TalkRequest, Hello_TalkResponse> {
    return self.makeAsyncBidirectionalStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? []
    )
  }
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
extension Hello_LandingServiceAsyncClientProtocol {
  public func talk(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions? = nil
  ) async throws -> Hello_TalkResponse {
    return try await self.performAsyncUnaryCall(
      path: Hello_LandingServiceClientMetadata.Methods.talk.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkInterceptors() ?? []
    )
  }

  public func talkOneAnswerMore(
    _ request: Hello_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Hello_TalkResponse> {
    return self.performAsyncServerStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkOneAnswerMore.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? []
    )
  }

  public func talkMoreAnswerOne<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) async throws -> Hello_TalkResponse where RequestStream: Sequence, RequestStream.Element == Hello_TalkRequest {
    return try await self.performAsyncClientStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  public func talkMoreAnswerOne<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) async throws -> Hello_TalkResponse where RequestStream: AsyncSequence & Sendable, RequestStream.Element == Hello_TalkRequest {
    return try await self.performAsyncClientStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  public func talkBidirectional<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Hello_TalkResponse> where RequestStream: Sequence, RequestStream.Element == Hello_TalkRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? []
    )
  }

  public func talkBidirectional<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Hello_TalkResponse> where RequestStream: AsyncSequence & Sendable, RequestStream.Element == Hello_TalkRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Hello_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? []
    )
  }
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public struct Hello_LandingServiceAsyncClient: Hello_LandingServiceAsyncClientProtocol {
  public var channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol?

  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Hello_LandingServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

public protocol Hello_LandingServiceClientInterceptorFactoryProtocol: Sendable {

  /// - Returns: Interceptors to use when invoking 'talk'.
  func makeTalkInterceptors() -> [ClientInterceptor<Hello_TalkRequest, Hello_TalkResponse>]

  /// - Returns: Interceptors to use when invoking 'talkOneAnswerMore'.
  func makeTalkOneAnswerMoreInterceptors() -> [ClientInterceptor<Hello_TalkRequest, Hello_TalkResponse>]

  /// - Returns: Interceptors to use when invoking 'talkMoreAnswerOne'.
  func makeTalkMoreAnswerOneInterceptors() -> [ClientInterceptor<Hello_TalkRequest, Hello_TalkResponse>]

  /// - Returns: Interceptors to use when invoking 'talkBidirectional'.
  func makeTalkBidirectionalInterceptors() -> [ClientInterceptor<Hello_TalkRequest, Hello_TalkResponse>]
}

public enum Hello_LandingServiceClientMetadata {
  public static let serviceDescriptor = GRPCServiceDescriptor(
    name: "LandingService",
    fullName: "hello.LandingService",
    methods: [
      Hello_LandingServiceClientMetadata.Methods.talk,
      Hello_LandingServiceClientMetadata.Methods.talkOneAnswerMore,
      Hello_LandingServiceClientMetadata.Methods.talkMoreAnswerOne,
      Hello_LandingServiceClientMetadata.Methods.talkBidirectional,
    ]
  )

  public enum Methods {
    public static let talk = GRPCMethodDescriptor(
      name: "Talk",
      path: "/hello.LandingService/Talk",
      type: GRPCCallType.unary
    )

    public static let talkOneAnswerMore = GRPCMethodDescriptor(
      name: "TalkOneAnswerMore",
      path: "/hello.LandingService/TalkOneAnswerMore",
      type: GRPCCallType.serverStreaming
    )

    public static let talkMoreAnswerOne = GRPCMethodDescriptor(
      name: "TalkMoreAnswerOne",
      path: "/hello.LandingService/TalkMoreAnswerOne",
      type: GRPCCallType.clientStreaming
    )

    public static let talkBidirectional = GRPCMethodDescriptor(
      name: "TalkBidirectional",
      path: "/hello.LandingService/TalkBidirectional",
      type: GRPCCallType.bidirectionalStreaming
    )
  }
}

/// To build a server, implement a class that conforms to this protocol.
public protocol Hello_LandingServiceProvider: CallHandlerProvider {
  var interceptors: Hello_LandingServiceServerInterceptorFactoryProtocol? { get }

  ///Unary RPC
  func talk(request: Hello_TalkRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Hello_TalkResponse>

  ///Server streaming RPC
  func talkOneAnswerMore(request: Hello_TalkRequest, context: StreamingResponseCallContext<Hello_TalkResponse>) -> EventLoopFuture<GRPCStatus>

  ///Client streaming RPC with random & sleep
  func talkMoreAnswerOne(context: UnaryResponseCallContext<Hello_TalkResponse>) -> EventLoopFuture<(StreamEvent<Hello_TalkRequest>) -> Void>

  ///Bidirectional streaming RPC
  func talkBidirectional(context: StreamingResponseCallContext<Hello_TalkResponse>) -> EventLoopFuture<(StreamEvent<Hello_TalkRequest>) -> Void>
}

extension Hello_LandingServiceProvider {
  public var serviceName: Substring {
    return Hello_LandingServiceServerMetadata.serviceDescriptor.fullName[...]
  }

  /// Determines, calls and returns the appropriate request handler, depending on the request's method.
  /// Returns nil for methods not handled by this service.
  public func handle(
    method name: Substring,
    context: CallHandlerContext
  ) -> GRPCServerHandlerProtocol? {
    switch name {
    case "Talk":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkInterceptors() ?? [],
        userFunction: self.talk(request:context:)
      )

    case "TalkOneAnswerMore":
      return ServerStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? [],
        userFunction: self.talkOneAnswerMore(request:context:)
      )

    case "TalkMoreAnswerOne":
      return ClientStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? [],
        observerFactory: self.talkMoreAnswerOne(context:)
      )

    case "TalkBidirectional":
      return BidirectionalStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? [],
        observerFactory: self.talkBidirectional(context:)
      )

    default:
      return nil
    }
  }
}

/// To implement a server, implement an object which conforms to this protocol.
@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
public protocol Hello_LandingServiceAsyncProvider: CallHandlerProvider, Sendable {
  static var serviceDescriptor: GRPCServiceDescriptor { get }
  var interceptors: Hello_LandingServiceServerInterceptorFactoryProtocol? { get }

  ///Unary RPC
  func talk(
    request: Hello_TalkRequest,
    context: GRPCAsyncServerCallContext
  ) async throws -> Hello_TalkResponse

  ///Server streaming RPC
  func talkOneAnswerMore(
    request: Hello_TalkRequest,
    responseStream: GRPCAsyncResponseStreamWriter<Hello_TalkResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws

  ///Client streaming RPC with random & sleep
  func talkMoreAnswerOne(
    requestStream: GRPCAsyncRequestStream<Hello_TalkRequest>,
    context: GRPCAsyncServerCallContext
  ) async throws -> Hello_TalkResponse

  ///Bidirectional streaming RPC
  func talkBidirectional(
    requestStream: GRPCAsyncRequestStream<Hello_TalkRequest>,
    responseStream: GRPCAsyncResponseStreamWriter<Hello_TalkResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws
}

@available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
extension Hello_LandingServiceAsyncProvider {
  public static var serviceDescriptor: GRPCServiceDescriptor {
    return Hello_LandingServiceServerMetadata.serviceDescriptor
  }

  public var serviceName: Substring {
    return Hello_LandingServiceServerMetadata.serviceDescriptor.fullName[...]
  }

  public var interceptors: Hello_LandingServiceServerInterceptorFactoryProtocol? {
    return nil
  }

  public func handle(
    method name: Substring,
    context: CallHandlerContext
  ) -> GRPCServerHandlerProtocol? {
    switch name {
    case "Talk":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkInterceptors() ?? [],
        wrapping: { try await self.talk(request: $0, context: $1) }
      )

    case "TalkOneAnswerMore":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? [],
        wrapping: { try await self.talkOneAnswerMore(request: $0, responseStream: $1, context: $2) }
      )

    case "TalkMoreAnswerOne":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? [],
        wrapping: { try await self.talkMoreAnswerOne(requestStream: $0, context: $1) }
      )

    case "TalkBidirectional":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Hello_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Hello_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? [],
        wrapping: { try await self.talkBidirectional(requestStream: $0, responseStream: $1, context: $2) }
      )

    default:
      return nil
    }
  }
}

public protocol Hello_LandingServiceServerInterceptorFactoryProtocol: Sendable {

  /// - Returns: Interceptors to use when handling 'talk'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkInterceptors() -> [ServerInterceptor<Hello_TalkRequest, Hello_TalkResponse>]

  /// - Returns: Interceptors to use when handling 'talkOneAnswerMore'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkOneAnswerMoreInterceptors() -> [ServerInterceptor<Hello_TalkRequest, Hello_TalkResponse>]

  /// - Returns: Interceptors to use when handling 'talkMoreAnswerOne'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkMoreAnswerOneInterceptors() -> [ServerInterceptor<Hello_TalkRequest, Hello_TalkResponse>]

  /// - Returns: Interceptors to use when handling 'talkBidirectional'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkBidirectionalInterceptors() -> [ServerInterceptor<Hello_TalkRequest, Hello_TalkResponse>]
}

public enum Hello_LandingServiceServerMetadata {
  public static let serviceDescriptor = GRPCServiceDescriptor(
    name: "LandingService",
    fullName: "hello.LandingService",
    methods: [
      Hello_LandingServiceServerMetadata.Methods.talk,
      Hello_LandingServiceServerMetadata.Methods.talkOneAnswerMore,
      Hello_LandingServiceServerMetadata.Methods.talkMoreAnswerOne,
      Hello_LandingServiceServerMetadata.Methods.talkBidirectional,
    ]
  )

  public enum Methods {
    public static let talk = GRPCMethodDescriptor(
      name: "Talk",
      path: "/hello.LandingService/Talk",
      type: GRPCCallType.unary
    )

    public static let talkOneAnswerMore = GRPCMethodDescriptor(
      name: "TalkOneAnswerMore",
      path: "/hello.LandingService/TalkOneAnswerMore",
      type: GRPCCallType.serverStreaming
    )

    public static let talkMoreAnswerOne = GRPCMethodDescriptor(
      name: "TalkMoreAnswerOne",
      path: "/hello.LandingService/TalkMoreAnswerOne",
      type: GRPCCallType.clientStreaming
    )

    public static let talkBidirectional = GRPCMethodDescriptor(
      name: "TalkBidirectional",
      path: "/hello.LandingService/TalkBidirectional",
      type: GRPCCallType.bidirectionalStreaming
    )
  }
}
