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


/// Usage: instantiate `Org_Feuyeux_Grpc_LandingServiceClient`, then call methods of this protocol to make API calls.
public protocol Org_Feuyeux_Grpc_LandingServiceClientProtocol: GRPCClient {
  var serviceName: String { get }
  var interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? { get }

  func talk(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>

  func talkOneAnswerMore(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions?,
    handler: @escaping (Org_Feuyeux_Grpc_TalkResponse) -> Void
  ) -> ServerStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>

  func talkMoreAnswerOne(
    callOptions: CallOptions?
  ) -> ClientStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>

  func talkBidirectional(
    callOptions: CallOptions?,
    handler: @escaping (Org_Feuyeux_Grpc_TalkResponse) -> Void
  ) -> BidirectionalStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>
}

extension Org_Feuyeux_Grpc_LandingServiceClientProtocol {
  public var serviceName: String {
    return "org.feuyeux.grpc.LandingService"
  }

  ///Unary RPC
  ///
  /// - Parameters:
  ///   - request: Request to send to Talk.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func talk(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeUnaryCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talk.path,
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
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions? = nil,
    handler: @escaping (Org_Feuyeux_Grpc_TalkResponse) -> Void
  ) -> ServerStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeServerStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkOneAnswerMore.path,
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
  ) -> ClientStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeClientStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
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
    handler: @escaping (Org_Feuyeux_Grpc_TalkResponse) -> Void
  ) -> BidirectionalStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeBidirectionalStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? [],
      handler: handler
    )
  }
}

@available(*, deprecated)
extension Org_Feuyeux_Grpc_LandingServiceClient: @unchecked Sendable {}

@available(*, deprecated, renamed: "Org_Feuyeux_Grpc_LandingServiceNIOClient")
public final class Org_Feuyeux_Grpc_LandingServiceClient: Org_Feuyeux_Grpc_LandingServiceClientProtocol {
  private let lock = Lock()
  private var _defaultCallOptions: CallOptions
  private var _interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol?
  public let channel: GRPCChannel
  public var defaultCallOptions: CallOptions {
    get { self.lock.withLock { return self._defaultCallOptions } }
    set { self.lock.withLockVoid { self._defaultCallOptions = newValue } }
  }
  public var interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? {
    get { self.lock.withLock { return self._interceptors } }
    set { self.lock.withLockVoid { self._interceptors = newValue } }
  }

  /// Creates a client for the org.feuyeux.grpc.LandingService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self._defaultCallOptions = defaultCallOptions
    self._interceptors = interceptors
  }
}

public struct Org_Feuyeux_Grpc_LandingServiceNIOClient: Org_Feuyeux_Grpc_LandingServiceClientProtocol {
  public var channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol?

  /// Creates a client for the org.feuyeux.grpc.LandingService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol Org_Feuyeux_Grpc_LandingServiceAsyncClientProtocol: GRPCClient {
  static var serviceDescriptor: GRPCServiceDescriptor { get }
  var interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? { get }

  func makeTalkCall(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions?
  ) -> GRPCAsyncUnaryCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>

  func makeTalkOneAnswerMoreCall(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions?
  ) -> GRPCAsyncServerStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>

  func makeTalkMoreAnswerOneCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncClientStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>

  func makeTalkBidirectionalCall(
    callOptions: CallOptions?
  ) -> GRPCAsyncBidirectionalStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Org_Feuyeux_Grpc_LandingServiceAsyncClientProtocol {
  public static var serviceDescriptor: GRPCServiceDescriptor {
    return Org_Feuyeux_Grpc_LandingServiceClientMetadata.serviceDescriptor
  }

  public var interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? {
    return nil
  }

  public func makeTalkCall(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncUnaryCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeAsyncUnaryCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talk.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkInterceptors() ?? []
    )
  }

  public func makeTalkOneAnswerMoreCall(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncServerStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeAsyncServerStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkOneAnswerMore.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? []
    )
  }

  public func makeTalkMoreAnswerOneCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncClientStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeAsyncClientStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  public func makeTalkBidirectionalCall(
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncBidirectionalStreamingCall<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse> {
    return self.makeAsyncBidirectionalStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? []
    )
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Org_Feuyeux_Grpc_LandingServiceAsyncClientProtocol {
  public func talk(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions? = nil
  ) async throws -> Org_Feuyeux_Grpc_TalkResponse {
    return try await self.performAsyncUnaryCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talk.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkInterceptors() ?? []
    )
  }

  public func talkOneAnswerMore(
    _ request: Org_Feuyeux_Grpc_TalkRequest,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Org_Feuyeux_Grpc_TalkResponse> {
    return self.performAsyncServerStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkOneAnswerMore.path,
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? []
    )
  }

  public func talkMoreAnswerOne<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) async throws -> Org_Feuyeux_Grpc_TalkResponse where RequestStream: Sequence, RequestStream.Element == Org_Feuyeux_Grpc_TalkRequest {
    return try await self.performAsyncClientStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  public func talkMoreAnswerOne<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) async throws -> Org_Feuyeux_Grpc_TalkResponse where RequestStream: AsyncSequence & Sendable, RequestStream.Element == Org_Feuyeux_Grpc_TalkRequest {
    return try await self.performAsyncClientStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkMoreAnswerOne.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? []
    )
  }

  public func talkBidirectional<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Org_Feuyeux_Grpc_TalkResponse> where RequestStream: Sequence, RequestStream.Element == Org_Feuyeux_Grpc_TalkRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? []
    )
  }

  public func talkBidirectional<RequestStream>(
    _ requests: RequestStream,
    callOptions: CallOptions? = nil
  ) -> GRPCAsyncResponseStream<Org_Feuyeux_Grpc_TalkResponse> where RequestStream: AsyncSequence & Sendable, RequestStream.Element == Org_Feuyeux_Grpc_TalkRequest {
    return self.performAsyncBidirectionalStreamingCall(
      path: Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkBidirectional.path,
      requests: requests,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? []
    )
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct Org_Feuyeux_Grpc_LandingServiceAsyncClient: Org_Feuyeux_Grpc_LandingServiceAsyncClientProtocol {
  public var channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol?

  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

public protocol Org_Feuyeux_Grpc_LandingServiceClientInterceptorFactoryProtocol: Sendable {

  /// - Returns: Interceptors to use when invoking 'talk'.
  func makeTalkInterceptors() -> [ClientInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]

  /// - Returns: Interceptors to use when invoking 'talkOneAnswerMore'.
  func makeTalkOneAnswerMoreInterceptors() -> [ClientInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]

  /// - Returns: Interceptors to use when invoking 'talkMoreAnswerOne'.
  func makeTalkMoreAnswerOneInterceptors() -> [ClientInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]

  /// - Returns: Interceptors to use when invoking 'talkBidirectional'.
  func makeTalkBidirectionalInterceptors() -> [ClientInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]
}

public enum Org_Feuyeux_Grpc_LandingServiceClientMetadata {
  public static let serviceDescriptor = GRPCServiceDescriptor(
    name: "LandingService",
    fullName: "org.feuyeux.grpc.LandingService",
    methods: [
      Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talk,
      Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkOneAnswerMore,
      Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkMoreAnswerOne,
      Org_Feuyeux_Grpc_LandingServiceClientMetadata.Methods.talkBidirectional,
    ]
  )

  public enum Methods {
    public static let talk = GRPCMethodDescriptor(
      name: "Talk",
      path: "/org.feuyeux.grpc.LandingService/Talk",
      type: GRPCCallType.unary
    )

    public static let talkOneAnswerMore = GRPCMethodDescriptor(
      name: "TalkOneAnswerMore",
      path: "/org.feuyeux.grpc.LandingService/TalkOneAnswerMore",
      type: GRPCCallType.serverStreaming
    )

    public static let talkMoreAnswerOne = GRPCMethodDescriptor(
      name: "TalkMoreAnswerOne",
      path: "/org.feuyeux.grpc.LandingService/TalkMoreAnswerOne",
      type: GRPCCallType.clientStreaming
    )

    public static let talkBidirectional = GRPCMethodDescriptor(
      name: "TalkBidirectional",
      path: "/org.feuyeux.grpc.LandingService/TalkBidirectional",
      type: GRPCCallType.bidirectionalStreaming
    )
  }
}

/// To build a server, implement a class that conforms to this protocol.
public protocol Org_Feuyeux_Grpc_LandingServiceProvider: CallHandlerProvider {
  var interceptors: Org_Feuyeux_Grpc_LandingServiceServerInterceptorFactoryProtocol? { get }

  ///Unary RPC
  func talk(request: Org_Feuyeux_Grpc_TalkRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Org_Feuyeux_Grpc_TalkResponse>

  ///Server streaming RPC
  func talkOneAnswerMore(request: Org_Feuyeux_Grpc_TalkRequest, context: StreamingResponseCallContext<Org_Feuyeux_Grpc_TalkResponse>) -> EventLoopFuture<GRPCStatus>

  ///Client streaming RPC with random & sleep
  func talkMoreAnswerOne(context: UnaryResponseCallContext<Org_Feuyeux_Grpc_TalkResponse>) -> EventLoopFuture<(StreamEvent<Org_Feuyeux_Grpc_TalkRequest>) -> Void>

  ///Bidirectional streaming RPC
  func talkBidirectional(context: StreamingResponseCallContext<Org_Feuyeux_Grpc_TalkResponse>) -> EventLoopFuture<(StreamEvent<Org_Feuyeux_Grpc_TalkRequest>) -> Void>
}

extension Org_Feuyeux_Grpc_LandingServiceProvider {
  public var serviceName: Substring {
    return Org_Feuyeux_Grpc_LandingServiceServerMetadata.serviceDescriptor.fullName[...]
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
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkInterceptors() ?? [],
        userFunction: self.talk(request:context:)
      )

    case "TalkOneAnswerMore":
      return ServerStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? [],
        userFunction: self.talkOneAnswerMore(request:context:)
      )

    case "TalkMoreAnswerOne":
      return ClientStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? [],
        observerFactory: self.talkMoreAnswerOne(context:)
      )

    case "TalkBidirectional":
      return BidirectionalStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? [],
        observerFactory: self.talkBidirectional(context:)
      )

    default:
      return nil
    }
  }
}

/// To implement a server, implement an object which conforms to this protocol.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol Org_Feuyeux_Grpc_LandingServiceAsyncProvider: CallHandlerProvider, Sendable {
  static var serviceDescriptor: GRPCServiceDescriptor { get }
  var interceptors: Org_Feuyeux_Grpc_LandingServiceServerInterceptorFactoryProtocol? { get }

  ///Unary RPC
  func talk(
    request: Org_Feuyeux_Grpc_TalkRequest,
    context: GRPCAsyncServerCallContext
  ) async throws -> Org_Feuyeux_Grpc_TalkResponse

  ///Server streaming RPC
  func talkOneAnswerMore(
    request: Org_Feuyeux_Grpc_TalkRequest,
    responseStream: GRPCAsyncResponseStreamWriter<Org_Feuyeux_Grpc_TalkResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws

  ///Client streaming RPC with random & sleep
  func talkMoreAnswerOne(
    requestStream: GRPCAsyncRequestStream<Org_Feuyeux_Grpc_TalkRequest>,
    context: GRPCAsyncServerCallContext
  ) async throws -> Org_Feuyeux_Grpc_TalkResponse

  ///Bidirectional streaming RPC
  func talkBidirectional(
    requestStream: GRPCAsyncRequestStream<Org_Feuyeux_Grpc_TalkRequest>,
    responseStream: GRPCAsyncResponseStreamWriter<Org_Feuyeux_Grpc_TalkResponse>,
    context: GRPCAsyncServerCallContext
  ) async throws
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension Org_Feuyeux_Grpc_LandingServiceAsyncProvider {
  public static var serviceDescriptor: GRPCServiceDescriptor {
    return Org_Feuyeux_Grpc_LandingServiceServerMetadata.serviceDescriptor
  }

  public var serviceName: Substring {
    return Org_Feuyeux_Grpc_LandingServiceServerMetadata.serviceDescriptor.fullName[...]
  }

  public var interceptors: Org_Feuyeux_Grpc_LandingServiceServerInterceptorFactoryProtocol? {
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
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkInterceptors() ?? [],
        wrapping: { try await self.talk(request: $0, context: $1) }
      )

    case "TalkOneAnswerMore":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkOneAnswerMoreInterceptors() ?? [],
        wrapping: { try await self.talkOneAnswerMore(request: $0, responseStream: $1, context: $2) }
      )

    case "TalkMoreAnswerOne":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkMoreAnswerOneInterceptors() ?? [],
        wrapping: { try await self.talkMoreAnswerOne(requestStream: $0, context: $1) }
      )

    case "TalkBidirectional":
      return GRPCAsyncServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Org_Feuyeux_Grpc_TalkRequest>(),
        responseSerializer: ProtobufSerializer<Org_Feuyeux_Grpc_TalkResponse>(),
        interceptors: self.interceptors?.makeTalkBidirectionalInterceptors() ?? [],
        wrapping: { try await self.talkBidirectional(requestStream: $0, responseStream: $1, context: $2) }
      )

    default:
      return nil
    }
  }
}

public protocol Org_Feuyeux_Grpc_LandingServiceServerInterceptorFactoryProtocol: Sendable {

  /// - Returns: Interceptors to use when handling 'talk'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkInterceptors() -> [ServerInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]

  /// - Returns: Interceptors to use when handling 'talkOneAnswerMore'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkOneAnswerMoreInterceptors() -> [ServerInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]

  /// - Returns: Interceptors to use when handling 'talkMoreAnswerOne'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkMoreAnswerOneInterceptors() -> [ServerInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]

  /// - Returns: Interceptors to use when handling 'talkBidirectional'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeTalkBidirectionalInterceptors() -> [ServerInterceptor<Org_Feuyeux_Grpc_TalkRequest, Org_Feuyeux_Grpc_TalkResponse>]
}

public enum Org_Feuyeux_Grpc_LandingServiceServerMetadata {
  public static let serviceDescriptor = GRPCServiceDescriptor(
    name: "LandingService",
    fullName: "org.feuyeux.grpc.LandingService",
    methods: [
      Org_Feuyeux_Grpc_LandingServiceServerMetadata.Methods.talk,
      Org_Feuyeux_Grpc_LandingServiceServerMetadata.Methods.talkOneAnswerMore,
      Org_Feuyeux_Grpc_LandingServiceServerMetadata.Methods.talkMoreAnswerOne,
      Org_Feuyeux_Grpc_LandingServiceServerMetadata.Methods.talkBidirectional,
    ]
  )

  public enum Methods {
    public static let talk = GRPCMethodDescriptor(
      name: "Talk",
      path: "/org.feuyeux.grpc.LandingService/Talk",
      type: GRPCCallType.unary
    )

    public static let talkOneAnswerMore = GRPCMethodDescriptor(
      name: "TalkOneAnswerMore",
      path: "/org.feuyeux.grpc.LandingService/TalkOneAnswerMore",
      type: GRPCCallType.serverStreaming
    )

    public static let talkMoreAnswerOne = GRPCMethodDescriptor(
      name: "TalkMoreAnswerOne",
      path: "/org.feuyeux.grpc.LandingService/TalkMoreAnswerOne",
      type: GRPCCallType.clientStreaming
    )

    public static let talkBidirectional = GRPCMethodDescriptor(
      name: "TalkBidirectional",
      path: "/org.feuyeux.grpc.LandingService/TalkBidirectional",
      type: GRPCCallType.bidirectionalStreaming
    )
  }
}