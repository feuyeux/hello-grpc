/// gRPC Client implementation for the Landing service.
///
/// This client demonstrates all four gRPC communication patterns:
/// 1. Unary RPC
/// 2. Server streaming RPC
/// 3. Client streaming RPC
/// 4. Bidirectional streaming RPC
///
/// The implementation follows standardized patterns for error handling,
/// logging, and graceful shutdown.
library;

import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:logging/logging.dart';

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'conn/conn.dart';

// Configuration constants
const int retryAttempts = 3;
const int retryDelaySeconds = 2;
const int iterationCount = 3;
const int requestDelayMs = 200;
const int sendDelayMs = 2;
const int requestTimeoutSeconds = 5;
const int defaultBatchSize = 5;

/// Main client class that manages gRPC communication
class Client {
  late final LandingServiceClient _stub;
  late final Logger _logger;
  final File _outputFile = File('log/hello_client.log');
  bool _shutdownRequested = false;

  /// Main entry point for the client
  Future<void> main(List<String> args) async {
    _configureLogging();
    _logger = Logger('HelloClient');
    _setupSignalHandling();

    _logger.info('Starting gRPC client [version: ${Utils.getVersion()}]');

    // Retry logic for connection
    for (var attempt = 1; attempt <= retryAttempts; attempt++) {
      if (_shutdownRequested) {
        _logger.info('Client shutting down, aborting connection attempts');
        return;
      }

      _logger.info('Connection attempt $attempt/$retryAttempts');

      try {
        final channel = await _createChannel();
        _stub = LandingServiceClient(
          channel,
          options: CallOptions(
            timeout: const Duration(seconds: requestTimeoutSeconds),
          ),
        );

        // Run all gRPC patterns
        final success = await _runGrpcCalls(
          const Duration(milliseconds: requestDelayMs),
          iterationCount,
        );

        await channel.shutdown();

        if (success || _shutdownRequested) {
          break;
        }
      } on Exception catch (e) {
        _logger.severe('Connection attempt $attempt failed: $e');
        if (attempt < retryAttempts && !_shutdownRequested) {
          _logger.info('Retrying in $retryDelaySeconds seconds...');
          await Future.delayed(const Duration(seconds: retryDelaySeconds));
        }
      }
    }

    if (_shutdownRequested) {
      _logger.info('Client execution was cancelled');
    } else {
      _logger.info('Client execution completed successfully');
    }
  }

  /// Configure logging for the application
  void _configureLogging() {
    // Create log directory if it doesn't exist
    final logDir = Directory('log');
    if (!logDir.existsSync()) {
      logDir.createSync();
    }

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((rec) {
      final message =
          '[${rec.time}] [${rec.level.name}] [${rec.loggerName}] ${rec.message}';
      // ignore: avoid_print
      print(message);
      _outputFile.writeAsStringSync('$message\n', mode: FileMode.append);
    });
  }

  /// Set up signal handling for graceful shutdown
  void _setupSignalHandling() {
    ProcessSignal.sigint.watch().listen((_) {
      _logger.info('Received shutdown signal, cancelling operations');
      _shutdownRequested = true;
    });

    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) {
        _logger.info('Received SIGTERM signal, cancelling operations');
        _shutdownRequested = true;
      });
    }
  }

  /// Create and configure the gRPC channel
  Future<ClientChannel> _createChannel() async {
    final envVars = Platform.environment;
    final grpcServer = envVars['GRPC_SERVER'] ?? '127.0.0.1';
    _logger.info('Connecting to server: $grpcServer');

    final ChannelCredentials credentials;
    if (Conn.isSecure) {
      _logger
        ..info('Using secure connection (TLS)')
        ..info('Root cert path: ${Conn.rootCertPath}');

      final rootCert = await File(Conn.rootCertPath).readAsBytes();
      credentials = ChannelCredentials.secure(
        certificates: rootCert,
        authority: 'hello.grpc.io',
      );
    } else {
      _logger.info('Using insecure connection');
      credentials = const ChannelCredentials.insecure();
    }

    return ClientChannel(
      grpcServer,
      port: Conn.getServerPort(),
      options: ChannelOptions(credentials: credentials),
    );
  }

  /// Run all gRPC call patterns multiple times
  Future<bool> _runGrpcCalls(Duration delay, int iterations) async {
    for (var iteration = 1; iteration <= iterations; iteration++) {
      if (_shutdownRequested) {
        return false;
      }

      _logger.info('====== Starting iteration $iteration/$iterations ======');

      try {
        // 1. Unary RPC
        _logger.info('----- Executing unary RPC -----');
        final unaryRequest =
            TalkRequest()
              ..data = '0'
              ..meta = 'DART';
        await executeUnaryCall(unaryRequest);

        // 2. Server streaming RPC
        _logger.info('----- Executing server streaming RPC -----');
        final serverStreamRequest =
            TalkRequest()
              ..data = '0,1,2'
              ..meta = 'DART';
        await executeServerStreamingCall(serverStreamRequest);

        // 3. Client streaming RPC
        _logger.info('----- Executing client streaming RPC -----');
        final response = await executeClientStreamingCall(_buildLinkRequests());
        _logResponse(response);

        // 4. Bidirectional streaming RPC
        _logger.info('----- Executing bidirectional streaming RPC -----');
        await executeBidirectionalStreamingCall(_buildLinkRequests());

        if (iteration < iterations && !_shutdownRequested) {
          _logger.info(
            'Waiting ${delay.inMilliseconds}ms before next iteration...',
          );
          await Future.delayed(delay);
        }
      } on Exception catch (e) {
        _logger.severe('Error in iteration $iteration: $e');
        return false;
      }
    }

    _logger.info('All gRPC calls completed successfully');
    return true;
  }

  /// Execute unary RPC call
  Future<void> executeUnaryCall(TalkRequest request) async {
    final requestId = 'unary-${DateTime.now().millisecondsSinceEpoch}';
    final metadata = <String, String>{
      'request-id': requestId,
      'client': 'dart-client',
    };

    _logger.info(
      'Sending unary request: data=${request.data}, meta=${request.meta}',
    );
    final startTime = DateTime.now();

    try {
      final response = await _stub.talk(
        request,
        options: CallOptions(metadata: metadata),
      );
      final duration = DateTime.now().difference(startTime);
      _logger.info('Unary call successful in ${duration.inMilliseconds}ms');
      _logResponse(response);
    } on GrpcError catch (e) {
      _logError(e, requestId, 'Talk');
      rethrow;
    }
  }

  /// Execute server streaming RPC call
  Future<void> executeServerStreamingCall(TalkRequest request) async {
    final requestId = 'server-stream-${DateTime.now().millisecondsSinceEpoch}';
    final metadata = <String, String>{
      'request-id': requestId,
      'client': 'dart-client',
    };

    _logger.info(
      'Starting server streaming with request: data=${request.data}, meta=${request.meta}',
    );
    final startTime = DateTime.now();

    try {
      var responseCount = 0;
      await for (final response in _stub.talkOneAnswerMore(
        request,
        options: CallOptions(metadata: metadata),
      )) {
        if (_shutdownRequested) {
          _logger.info('Server streaming cancelled');
          return;
        }
        responseCount++;
        _logger.info('Received server streaming response #$responseCount:');
        _logResponse(response);
      }

      final duration = DateTime.now().difference(startTime);
      _logger.info(
        'Server streaming completed: received $responseCount responses in ${duration.inMilliseconds}ms',
      );
    } on GrpcError catch (e) {
      _logError(e, requestId, 'TalkOneAnswerMore');
      rethrow;
    }
  }

  /// Execute client streaming RPC call
  Future<TalkResponse> executeClientStreamingCall(
    List<TalkRequest> requests,
  ) async {
    final requestId = 'client-stream-${DateTime.now().millisecondsSinceEpoch}';
    final metadata = <String, String>{
      'request-id': requestId,
      'client': 'dart-client',
    };

    _logger.info('Starting client streaming with ${requests.length} requests');
    final startTime = DateTime.now();

    try {
      Stream<TalkRequest> generateRequests() async* {
        var requestCount = 0;
        for (final request in requests) {
          if (_shutdownRequested) {
            _logger.info('Client streaming cancelled');
            return;
          }
          requestCount++;
          _logger.info(
            'Sending client streaming request #$requestCount: data=${request.data}, meta=${request.meta}',
          );
          yield request;
          await Future.delayed(const Duration(milliseconds: sendDelayMs));
        }
      }

      final response = await _stub.talkMoreAnswerOne(
        generateRequests(),
        options: CallOptions(metadata: metadata),
      );

      final duration = DateTime.now().difference(startTime);
      _logger.info(
        'Client streaming completed: sent ${requests.length} requests in ${duration.inMilliseconds}ms',
      );
      return response;
    } on GrpcError catch (e) {
      _logError(e, requestId, 'TalkMoreAnswerOne');
      rethrow;
    }
  }

  /// Execute bidirectional streaming RPC call
  Future<void> executeBidirectionalStreamingCall(
    List<TalkRequest> requests,
  ) async {
    final requestId = 'bidirectional-${DateTime.now().millisecondsSinceEpoch}';
    final metadata = <String, String>{
      'request-id': requestId,
      'client': 'dart-client',
    };

    _logger.info(
      'Starting bidirectional streaming with ${requests.length} requests',
    );
    final startTime = DateTime.now();

    try {
      Stream<TalkRequest> generateRequests() async* {
        var requestCount = 0;
        for (final request in requests) {
          if (_shutdownRequested) {
            _logger.info('Bidirectional streaming cancelled');
            return;
          }
          requestCount++;
          _logger.info(
            'Sending bidirectional streaming request #$requestCount: data=${request.data}, meta=${request.meta}',
          );
          yield request;
          await Future.delayed(const Duration(milliseconds: sendDelayMs));
        }
      }

      var responseCount = 0;
      await for (final response in _stub.talkBidirectional(
        generateRequests(),
        options: CallOptions(metadata: metadata),
      )) {
        if (_shutdownRequested) {
          _logger.info('Bidirectional streaming cancelled');
          return;
        }
        responseCount++;
        _logger.info(
          'Received bidirectional streaming response #$responseCount:',
        );
        _logResponse(response);
      }

      final duration = DateTime.now().difference(startTime);
      _logger.info(
        'Bidirectional streaming completed in ${duration.inMilliseconds}ms',
      );
    } on GrpcError catch (e) {
      _logError(e, requestId, 'TalkBidirectional');
      rethrow;
    }
  }

  /// Build a list of link requests for testing streaming RPCs
  List<TalkRequest> _buildLinkRequests() {
    return List.generate(
      defaultBatchSize,
      (index) =>
          TalkRequest()
            ..data = Utils.randomId(5)
            ..meta = 'DART',
    );
  }

  /// Log response details
  void _logResponse(TalkResponse response) {
    _logger.info(
      'Response status: ${response.status}, results: ${response.results.length}',
    );
    for (var i = 0; i < response.results.length; i++) {
      final result = response.results[i];
      final kv = result.kv;
      _logger.info(
        '  Result #${i + 1}: id=${result.id}, type=${result.type}, '
        'meta=${kv['meta']}, id=${kv['id']}, idx=${kv['idx']}, data=${kv['data']}',
      );
    }
  }

  /// Log error with context
  void _logError(GrpcError error, String requestId, String method) {
    _logger.severe(
      'Request failed - request_id: $requestId, method: $method, '
      'error_code: ${error.code}, message: ${error.message}',
    );
  }
}
