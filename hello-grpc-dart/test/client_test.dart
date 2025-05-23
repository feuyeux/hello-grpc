import 'package:test/test.dart';
import 'package:grpc/grpc.dart';
import 'package:hello_grpc_dart/lib/client.dart' as actual_client; // actual client code
import 'package:hello_grpc_dart/lib/common/landing.pbgrpc.dart'; // for LadingRequest, LandingResponse etc.
import 'dart:async';

// --- Mock gRPC Service Implementation ---

class MockLandingServiceClient extends LandingServiceClient {
  // Mock data and behaviors will be defined here
  MockLandingServiceClient(ClientChannelBase channel, {CallOptions? options}) // Prompt implies non-nullable options for the mock's own constructor
      : super(channel, options: options ?? CallOptions()); // Base class LandingServiceClient has nullable options. Providing default if super needs non-nullable.

  // --- Unary Call Mock ---
  // Fields are specified as non-nullable in the prompt's class diagram.
  // However, their usage in methods (checking for null) implies they should be nullable.
  // Making them nullable to align with the method logic shown in the prompt.
  LandingResponse? _unaryResponse;
  LandingRequest? _unaryRequestReceived;
  Function(LandingRequest)? _unaryRequestHandler;

  void setUnaryResponse(LandingResponse response) {
    _unaryResponse = response;
  }
  
  void setUnaryRequestHandler(Function(LandingRequest) handler) {
    _unaryRequestHandler = handler;
  }

  // Using 'unaryCall' (corrected from 'uaryCall').
  @override
  Future<LandingResponse> unaryCall(LandingRequest request, {CallOptions? options}) async { // Prompt implies non-nullable options.
    _unaryRequestReceived = request;
    if (_unaryRequestHandler != null) {
      return _unaryRequestHandler!(request);
    }
    if (_unaryResponse != null) {
      return _unaryResponse!;
    }
    return LandingResponse()..message = 'Default mock unary response';
  }

  // --- Server Streaming Mock ---
  StreamController<LandingResponse>? _serverStreamingController; // Nullable
  LandingRequest? _serverStreamingRequestReceived; // Nullable
  Function(LandingRequest)? _serverStreamingRequestHandler; // Nullable


  void setupServerStreamingResponse(List<LandingResponse> responses, [Function(LandingRequest)? requestHandler]) { // requestHandler nullable
    _serverStreamingController = StreamController<LandingResponse>();
    if (requestHandler != null) _serverStreamingRequestHandler = requestHandler;
    for (var res in responses) {
      _serverStreamingController!.add(res);
    }
    _serverStreamingController!.close();
  }

  @override
  ResponseStream<LandingResponse> serverStreamingCall(LandingRequest request, {CallOptions? options}) { // Prompt implies non-nullable options.
    _serverStreamingRequestReceived = request;
     if (_serverStreamingRequestHandler != null) {
      _serverStreamingRequestHandler!(request);
    }
    if (_serverStreamingController == null) {
      _serverStreamingController = StreamController<LandingResponse>()..close();
    }
    return ResponseStream(_serverStreamingController!.stream);
  }

  // --- Client Streaming Mock ---
  LandingResponse? _clientStreamingResponse; // Nullable
  List<LandingRequest> _clientStreamingRequestsReceived = [];
  Function(Stream<LandingRequest>)? _clientStreamingRequestHandler; // Nullable

  void setClientStreamingResponse(LandingResponse response) {
    _clientStreamingResponse = response;
  }
  
  void setClientStreamingRequestHandler(Function(Stream<LandingRequest>) handler) {
    _clientStreamingRequestHandler = handler;
  }

  @override
  Future<LandingResponse> clientStreamingCall(Stream<LandingRequest> request, {CallOptions? options}) async { // Prompt implies non-nullable options.
    _clientStreamingRequestsReceived.clear();
    await for (var req in request) {
      _clientStreamingRequestsReceived.add(req);
    }
    if (_clientStreamingRequestHandler != null) {
       return _clientStreamingRequestHandler!(Stream.fromIterable(_clientStreamingRequestsReceived));
    }
    if (_clientStreamingResponse != null) {
      return _clientStreamingResponse!;
    }
    return LandingResponse()..message = 'Default mock client streaming response';
  }

  // --- Bidirectional Streaming Mock ---
  StreamController<LandingResponse>? _bidiResponseController; // Nullable
  List<LandingRequest> _bidiRequestsReceived = [];
  Function(Stream<LandingRequest>, StreamController<LandingResponse>)? _bidiStreamingHandler; // Nullable

  void setupBidiStreaming(Function(Stream<LandingRequest>, StreamController<LandingResponse>) handler) {
    _bidiStreamingHandler = handler;
  }

  @override
  ResponseStream<LandingResponse> biStreamingCall(Stream<LandingRequest> request, {CallOptions? options}) { // Prompt implies non-nullable options.
    _bidiRequestsReceived.clear();
    _bidiResponseController = StreamController<LandingResponse>();

    if (_bidiStreamingHandler != null) {
      request.listen((req) {
        _bidiRequestsReceived.add(req);
      }).onDone(() {
         _bidiStreamingHandler!(Stream.fromIterable(_bidiRequestsReceived), _bidiResponseController!);
      });
    } else {
      request.listen((req) {
        _bidiRequestsReceived.add(req);
      }).onDone(() {
        _bidiResponseController!.close();
      });
    }
    return ResponseStream(_bidiResponseController!.stream);
  }
}

void main() {
  group('Client gRPC Tests', () {
    // Per prompt, these are non-nullable. 'late' is appropriate for setUp initialization.
    late ClientChannelBase mockChannel;
    late MockLandingServiceClient mockClient;
    late actual_client.Client actualClientInstance;

    setUp(() {
      mockChannel = ClientChannel('localhost', port: 1234, options: ChannelOptions(credentials: ChannelCredentials.insecure()));
      // The prompt's MockLandingServiceClient constructor signature has non-nullable options.
      // Passing CallOptions() to match.
      mockClient = MockLandingServiceClient(mockChannel, options: CallOptions()); 
      actualClientInstance = actual_client.Client(); 
      // TODO: Modify actual_client.Client to allow injecting mockClient
    });

    tearDown(() {
      mockChannel.shutdown();
    });

    test('Unary call sends correct request and handles response', () async {
      final request = LandingRequest()..name = 'TestUnary';
      final expectedResponse = LandingResponse()..message = 'Unary response for TestUnary';
      
      mockClient.setUnaryResponse(expectedResponse);
      
      // Pass CallOptions() to match the prompt's unaryCall signature for options.
      final response = await mockClient.unaryCall(request, options: CallOptions()); 
      
      expect(mockClient._unaryRequestReceived!.name, 'TestUnary'); // Null assertion on nullable field
      expect(response.message, 'Unary response for TestUnary');
    });

    test('Server streaming call sends request and processes stream', () async {
      final request = LandingRequest()..name = 'TestServerStream';
      final responses = [
        LandingResponse()..message = 'Stream msg 1',
        LandingResponse()..message = 'Stream msg 2',
      ];
      mockClient.setupServerStreamingResponse(responses);

      final List<String> receivedMessages = [];
      final stream = mockClient.serverStreamingCall(request, options: CallOptions()); // Pass options
      await for (var response in stream) {
        receivedMessages.add(response.message);
      }

      expect(mockClient._serverStreamingRequestReceived!.name, 'TestServerStream'); // Null assertion
      expect(receivedMessages, ['Stream msg 1', 'Stream msg 2']);
    });

    test('Client streaming call sends stream and handles response', () async {
      final requests = [
        LandingRequest()..name = 'ClientStream 1',
        LandingRequest()..name = 'ClientStream 2',
      ];
      final expectedResponse = LandingResponse()..message = 'Response after client stream';
      mockClient.setClientStreamingResponse(expectedResponse);

      final clientStreamController = StreamController<LandingRequest>();
      Future<LandingResponse> responseFuture = mockClient.clientStreamingCall(clientStreamController.stream, options: CallOptions()); // Pass options
      
      for (var req in requests) {
        clientStreamController.add(req);
      }
      await clientStreamController.close();
      
      final response = await responseFuture;

      expect(mockClient._clientStreamingRequestsReceived.length, 2);
      expect(mockClient._clientStreamingRequestsReceived[0].name, 'ClientStream 1');
      expect(mockClient._clientStreamingRequestsReceived[1].name, 'ClientStream 2');
      expect(response.message, 'Response after client stream');
    });

    test('Bidirectional streaming call sends and receives streams', () async {
      final clientMessages = [
        LandingRequest()..name = 'BidiMsg1',
        LandingRequest()..name = 'BidiMsg2',
      ];

      mockClient.setupBidiStreaming((Stream<LandingRequest> requestStream, StreamController<LandingResponse> responseStreamCtl) async {
        int count = 0;
        await for (var req in requestStream) {
          responseStreamCtl.add(LandingResponse()..message = 'Server got ${req.name}');
          count++;
        }
        expect(count, clientMessages.length); 
        await responseStreamCtl.close();
      });
      
      final clientStreamController = StreamController<LandingRequest>();
      final serverResponseStream = mockClient.biStreamingCall(clientStreamController.stream, options: CallOptions()); // Pass options

      for (var msg in clientMessages) {
        clientStreamController.add(msg);
      }
      await clientStreamController.close(); 

      final List<String> serverResponses = [];
      await for (var res in serverResponseStream) {
        serverResponses.add(res.message);
      }
      
      expect(mockClient._bidiRequestsReceived.length, 2);
      expect(mockClient._bidiRequestsReceived[0].name, 'BidiMsg1');
      expect(serverResponses, ['Server got BidiMsg1', 'Server got BidiMsg2']);
    });

  });
}
