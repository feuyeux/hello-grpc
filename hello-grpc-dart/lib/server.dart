import 'dart:async';
import 'dart:io';
import 'dart:io' as io show Platform;

import 'package:grpc/grpc.dart' as grpc;
import 'package:logging/logging.dart';

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'conn/conn.dart';

/// Available greetings in different languages
const List<String> greetings = [
  'Hello', // English
  'Bonjour', // French
  'Hola', // Spanish
  'こんにちは', // Japanese
  'Ciao', // Italian
  '안녕하세요', // Korean
];

/// Translation responses for different greetings
final Map<String, String> translations = {
  '你好': '非常感谢',
  'Hello': 'Thank you very much',
  'Bonjour': 'Merci beaucoup',
  'Hola': 'Muchas Gracias',
  'こんにちは': 'どうも ありがとう ございます',
  'Ciao': 'Mille Grazie',
  '안녕하세요': '대단히 감사합니다',
};

/// Tracing headers that should be forwarded to backend services
const List<String> tracingHeaders = [
  'x-request-id',
  'x-b3-traceid',
  'x-b3-spanid',
  'x-b3-parentspanid',
  'x-b3-sampled',
  'x-b3-flags',
  'x-ot-span-context',
];

/// Main server class that initializes and manages the gRPC server
class Server {
  /// Logger instance for this class
  late final Logger _logger;

  /// Path to the log file
  final String _logFile = 'hello_server.log';

  /// Main entry point for the server
  Future<void> main(List<String> args) async {
    // Set up logging
    _configureLogging();
    _logger = Logger('HelloServer');

    try {
      // Get environment variables
      final envVars = io.Platform.environment;
      final user = envVars['USER'];
      _logger.info('User: $user');

      // Configure server port
      final serverPort = Conn.getServerPort();

      // Create server with service implementation
      final server = grpc.Server.create(
        services: [LandingService(logger: _logger)],
      );

      // Set up signal handling for graceful shutdown
      _setupSignalHandling(server);

      // Start server with TLS if configured
      if (Conn.isSecure) {
        _logger
          ..info('Starting server in secure mode (TLS)')
          ..info('Certificate path: ${Conn.certPath}')
          ..info('Key path: ${Conn.keyPath}');

        // Read certificate files
        final certificate = await File(Conn.certPath).readAsBytes();
        final privateKey = await File(Conn.keyPath).readAsBytes();

        final credentials = grpc.ServerTlsCredentials(
          certificate: certificate,
          privateKey: privateKey,
        );

        await server.serve(
          address: '0.0.0.0',
          port: serverPort,
          security: credentials,
        );
      } else {
        _logger.info('Starting server in insecure mode');
        await server.serve(address: '0.0.0.0', port: serverPort);
      }

      _logger
        ..info('Server listening on port ${server.port}...')
        ..info('Version: ${Utils.getVersion()}');
    } on Exception catch (e, stackTrace) {
      _logger
        ..severe('Server failed to start: $e')
        ..fine('Stack trace: $stackTrace');
      exit(1);
    }
  }

  /// Configure logging for the application
  void _configureLogging() {
    // Create log directory if it doesn't exist
    final logDir = Directory('log');
    if (!logDir.existsSync()) {
      logDir.createSync();
    }

    final outputFile = File('log/$_logFile');

    // Configure root logger
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((rec) {
      // Log to console using logger instead of print
      _logger.info('${rec.level.name}: ${rec.time}: ${rec.message}');

      // Write to log file
      outputFile.writeAsStringSync(
        '${rec.time} | ${rec.level} | ${rec.message}\n',
        mode: FileMode.append,
      );
    });
  }

  /// Set up signal handling for graceful shutdown
  void _setupSignalHandling(grpc.Server server) {
    // Handle SIGINT (Ctrl+C)
    ProcessSignal.sigint.watch().listen((_) {
      _logger.info('Received SIGINT signal, shutting down server...');
      server.shutdown().then((_) {
        _logger.info('Server shutdown complete');
        exit(0);
      });
    });

    // Handle SIGTERM (not supported on Windows)
    if (!io.Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) {
        _logger.info('Received SIGTERM signal, shutting down server...');
        server.shutdown().then((_) {
          _logger.info('Server shutdown complete');
          exit(0);
        });
      });
    }
  }
}

/// Implementation of the gRPC LandingService
class LandingService extends LandingServiceBase {
  /// Constructor
  LandingService({required this.logger});

  /// Logger instance
  final Logger logger;

  /// Backend client for proxy mode (not implemented in this version)
  // final LandingServiceClient? _backendClient;

  /// Create response result with appropriate data
  ///
  /// [id] The request ID (typically a language index)
  TalkResult createResponse(String id) {
    // Parse the ID as an integer
    int index;
    try {
      index = int.parse(id);

      // Check for index out of bounds
      if (index < 0 || index >= greetings.length) {
        index = 0;
      }
    } on Exception {
      // Default to first greeting on parsing error
      index = 0;
    }

    // Get the greeting for this index
    final hello = greetings[index];

    // Create key-value map for response
    final kv = {
      'id': Utils.getUuid(),
      'idx': id,
      'data': '$hello,${translations[hello]!}',
      'meta': 'DART',
    };

    // Create result
    final result =
        TalkResult()
          ..id = Utils.timestamp()
          ..type = ResultType.OK;

    result.kv.addAll(kv);
    return result;
  }

  /// Implements the unary RPC method
  @override
  Future<TalkResponse> talk(grpc.ServiceCall call, TalkRequest request) async {
    final requestId = 'unary-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('Talk', call, requestId);

    logger.info(
      'REQUEST: method=Talk, request_id=$requestId, data=${request.data}, meta=${request.meta}',
    );

    try {
      // Create response
      final response = TalkResponse()..status = 200;
      response.results.add(createResponse(request.data));

      logger.info('RESPONSE: method=Talk, request_id=$requestId, status=200');
      return response;
    } on Exception catch (e) {
      logger.severe('ERROR: method=Talk, request_id=$requestId, error=$e');
      rethrow;
    }
  }

  /// Implements the server streaming RPC method
  @override
  Stream<TalkResponse> talkOneAnswerMore(
    grpc.ServiceCall call,
    TalkRequest request,
  ) async* {
    final requestId = 'server-stream-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('TalkOneAnswerMore', call, requestId);

    logger.info(
      'REQUEST: method=TalkOneAnswerMore, request_id=$requestId, data=${request.data}, meta=${request.meta}',
    );

    try {
      // Split input data by comma
      final items = request.data.split(',');

      // Generate a response for each item
      for (final item in items) {
        final response = TalkResponse()..status = 200;
        response.results.add(createResponse(item));
        yield response;
      }

      logger.info(
        'RESPONSE: method=TalkOneAnswerMore, request_id=$requestId, items=${items.length}',
      );
    } on Exception catch (e) {
      logger.severe(
        'ERROR: method=TalkOneAnswerMore, request_id=$requestId, error=$e',
      );
      rethrow;
    }
  }

  /// Implements the client streaming RPC method
  @override
  Future<TalkResponse> talkMoreAnswerOne(
    grpc.ServiceCall call,
    Stream<TalkRequest> requests,
  ) async {
    final requestId = 'client-stream-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('TalkMoreAnswerOne', call, requestId);

    logger.info('REQUEST: method=TalkMoreAnswerOne, request_id=$requestId');

    try {
      // Create response
      final response = TalkResponse()..status = 200;
      var requestCount = 0;

      // Process all incoming requests
      await for (final request in requests) {
        requestCount++;
        logger.info(
          'Client stream item #$requestCount - data=${request.data}, meta=${request.meta}',
        );
        response.results.add(createResponse(request.data));
      }

      logger.info(
        'RESPONSE: method=TalkMoreAnswerOne, request_id=$requestId, requests=$requestCount',
      );
      return response;
    } on Exception catch (e) {
      logger.severe(
        'ERROR: method=TalkMoreAnswerOne, request_id=$requestId, error=$e',
      );
      rethrow;
    }
  }

  /// Implements the bidirectional streaming RPC method
  @override
  Stream<TalkResponse> talkBidirectional(
    grpc.ServiceCall call,
    Stream<TalkRequest> requests,
  ) async* {
    final requestId = 'bidirectional-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('TalkBidirectional', call, requestId);

    logger.info('REQUEST: method=TalkBidirectional, request_id=$requestId');

    try {
      var requestCount = 0;
      // Process each request and yield a response
      await for (final request in requests) {
        requestCount++;
        logger.info(
          'Bidirectional stream item #$requestCount - data=${request.data}, meta=${request.meta}',
        );

        final response = TalkResponse()..status = 200;
        response.results.add(createResponse(request.data));
        yield response;
      }

      logger.info(
        'RESPONSE: method=TalkBidirectional, request_id=$requestId, requests=$requestCount',
      );
    } on Exception catch (e) {
      logger.severe(
        'ERROR: method=TalkBidirectional, request_id=$requestId, error=$e',
      );
      rethrow;
    }
  }

  /// Log request metadata for debugging
  ///
  /// [methodName] Name of the RPC method
  /// [call] The service call containing metadata
  /// [requestId] Unique identifier for this request
  void _logMetadata(
    String methodName,
    grpc.ServiceCall call,
    String requestId,
  ) {
    final clientMetadata = call.clientMetadata;

    if (clientMetadata == null || clientMetadata.isEmpty) {
      logger.fine('$methodName - request_id=$requestId - No metadata present');
      return;
    }

    for (final entry in clientMetadata.entries) {
      logger.fine(
        '$methodName - request_id=$requestId - header: ${entry.key}=${entry.value}',
      );
    }
  }
}
