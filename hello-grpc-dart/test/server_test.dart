import 'package:test/test.dart';
import 'package:grpc/grpc.dart' as grpc;
import 'package:hello_grpc_dart/lib/server.dart'; // Imports LandingServiceImpl
import 'package:hello_grpc_dart/lib/common/landing.pbgrpc.dart'; // For LandingRequest, LandingResponse
import 'package:hello_grpc_dart/lib/common/utils.dart'; // For Utils
import 'dart:async';
import 'dart:io' show Platform;

// Mock ServiceCall for testing handlers
// The actual ServiceCall is complex. This is a simplified mock.
class MockServiceCall extends grpc.ServiceCall {
  final Map<String, String> _clientMetadata = {};
  StreamController<List<int>> _incomingMessagesController;
  StreamController<List<int>> _outgoingMessagesController;

  MockServiceCall() : super(null, null, null, null, null, null, null) { // Passing nulls as we won't use real channel features
    _incomingMessagesController = StreamController<List<int>>();
    _outgoingMessagesController = StreamController<List<int>>();
  }

  @override
  Map<String, String> get clientMetadata => _clientMetadata;

  // Not typically needed for handler unit tests unless specific metadata is tested
  void setClientMetadata(String key, String value) {
    _clientMetadata[key] = value;
  }
  
  // Methods to simulate client actions for streaming tests
  void sendClientMessage(List<int> message) => _incomingMessagesController.add(message);
  void closeClientStream() => _incomingMessagesController.close();
  Stream<List<int>> get serverResponseStream => _outgoingMessagesController.stream;

  // ServiceCall required overrides that might not be used by handlers directly
  @override
  Future<void> get headers => Future.value(); // As per current prompt
  @override
  bool get isCanceled => false; // Simplification
  @override
  Stream<grpc.GrpcMessage> get incomingMessages => _incomingMessagesController.stream.map((data) => grpc.GrpcMessage(data)); // As per current prompt
  @override
  StreamSink<grpc.GrpcMessage> get outgoingMessages => _outgoingMessagesController.sink.transform(
    StreamTransformer.fromHandlers(handleData: (grpc.GrpcMessage data, EventSink<List<int>> sink) {
        sink.add(data.frame);
    })
  );
  @override
  Future<void> get trailers => Future.value(); // As per current prompt
  @override
  Function() get onCancel => () {}; // No-op
  @override
  set onCancel(Function() cb) {} // No-op
}


void main() {
  group('Server Handler Tests (LandingServiceImpl)', () {
    late LandingServiceImpl serviceImpl; // Use 'late' as per prompt
    late MockServiceCall mockCall; // Use 'late'

    setUp(() {
      serviceImpl = LandingServiceImpl(); // As per prompt (no logger)
      mockCall = MockServiceCall();
      // Clear any relevant environment variables before each test
      Platform.environment.remove('GRPC_HELLO_BACKEND');
      Platform.environment.remove('GRPC_HELLO_BACKEND_PORT');
    });

    tearDown(() {
      // Restore environment variables if needed, though typically for server tests
      // we set them up per test.
    });

    test('uaryCall returns correct response', () async { // Test name 'uaryCall' as per prompt
      final request = LandingRequest()..name = 'Test';
      // Calling serviceImpl.uaryCall as per prompt's test code.
      final response = await serviceImpl.uaryCall(mockCall, request); 

      expect(response.message, contains('Hello Test'));
      expect(response.id, isNotEmpty);
      // expect(response.version, Utils.getVersionSync()); // Utils.getVersionSync() needs context
    });

    test('serverStreamingCall returns multiple responses', () async {
      final request = LandingRequest()..name = 'StreamTest';
      // Calling serviceImpl.serverStreamingCall as per prompt's test code.
      final responseStream = serviceImpl.serverStreamingCall(mockCall, request);
      
      int count = 0;
      await for (var response in responseStream) {
        expect(response.message, contains('Hello StreamTest'));
        expect(response.id, isNotEmpty);
        count++;
      }
      // Default server stream sends 5 messages according to prompt's assertion.
      expect(count, 5); 
    });

    test('clientStreamingCall processes stream and returns summary', () async {
      final requests = [
        LandingRequest()..name = 'Client1',
        LandingRequest()..name = 'Client2',
        LandingRequest()..name = 'Client3',
      ];

      final requestStreamController = StreamController<LandingRequest>();
      // Calling serviceImpl.clientStreamingCall as per prompt's test code.
      Future<LandingResponse> serviceResponseFuture = serviceImpl.clientStreamingCall(mockCall, requestStreamController.stream);

      for (var req in requests) {
        requestStreamController.add(req);
      }
      await requestStreamController.close();

      final response = await serviceResponseFuture;
      expect(response.message, contains('Received 3 messages. Names: Client1, Client2, Client3'));
    });
    
    test('biStreamingCall echoes messages', () async {
      final clientMessages = [
        LandingRequest()..name = 'Bidi1',
        LandingRequest()..name = 'Bidi2',
      ];
      final clientStreamController = StreamController<LandingRequest>();
      // Calling serviceImpl.biStreamingCall as per prompt's test code.
      final serverResponseStream = serviceImpl.biStreamingCall(mockCall, clientStreamController.stream);
      
      List<String> receivedFromServer = []; // message is non-nullable in prompt's LandingResponse
      var serverListen = serverResponseStream.listen((response) {
        receivedFromServer.add(response.message);
      });

      for (var msg in clientMessages) {
        clientStreamController.add(msg);
        // Allow some time for processing, simplistic way
        await Future.delayed(Duration(milliseconds: 10)); 
      }
      await clientStreamController.close();
      
      await serverListen.asFuture(); // Wait for server stream to finish

      expect(receivedFromServer.length, clientMessages.length);
      expect(receivedFromServer[0], contains('Bidi1'));
      expect(receivedFromServer[1], contains('Bidi2'));
    });

    group('Proxy Logic Tests (GRPC_HELLO_BACKEND set)', () {
      test('uaryCall with proxy (Conceptual - requires client mock)', () async {
        Platform.environment['GRPC_HELLO_BACKEND'] = 'fakehost';
        Platform.environment['GRPC_HELLO_BACKEND_PORT'] = '1234';
            
        final request = LandingRequest()..name = 'TestProxy';
        try {
          // Calling serviceImpl.uaryCall as per prompt's test code.
          final response = await serviceImpl.uaryCall(mockCall, request);
          // If it returns a normal response without error, proxying isn't working as expected
          // or the mock setup for the internal client is missing.
          // For now, we'll assume it might throw if it can't connect.
          // This assertion depends on how the actual proxy code handles connection errors.
          expect(response.message, isNot(startsWith('Hello TestProxy from Dart gRPC server at')));
        } catch (e) {
          // Expecting an error because 'fakehost:1234' is not real.
          // This is a weak test for proxying.
          expect(e, isA<Exception>()); // Or specific gRPC error
        }
      });
    });
  });
}
