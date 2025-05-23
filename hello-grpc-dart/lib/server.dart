import 'dart:io';
import 'dart:async';
import 'dart:io' as io show Platform;

import 'package:grpc/grpc.dart' as grpc;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'package:hello_grpc_dart/common/utils.dart';
import 'src/generated/landing.pbgrpc.dart';
import 'conn/conn.dart';

/// Available greetings in different languages
const List<String> greetings = [
  "Hello",       // English
  "Bonjour",     // French
  "Hola",        // Spanish
  "こんにちは",    // Japanese
  "Ciao",        // Italian
  "안녕하세요"     // Korean
];

/// Translation responses for different greetings
final Map<String, String> translations = {
  "你好": "非常感谢",
  "Hello": "Thank you very much",
  "Bonjour": "Merci beaucoup",
  "Hola": "Muchas Gracias",
  "こんにちは": "どうも ありがとう ございます",
  "Ciao": "Mille Grazie",
  "안녕하세요": "대단히 감사합니다"
};

/// Tracing headers that should be forwarded to backend services
const List<String> tracingHeaders = [
  'x-request-id',
  'x-b3-traceid',
  'x-b3-spanid',
  'x-b3-parentspanid',
  'x-b3-sampled',
  'x-b3-flags',
  'x-ot-span-context'
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
      final Map<String, String> envVars = io.Platform.environment;
      final String? user = envVars['USER'];
      _logger.info("User: $user");
      
      // Configure server port
      final int serverPort = Conn.getServerPort();
      
      // Create server with service implementation
      final server = grpc.Server([
        LandingService(logger: _logger)
      ]);
      
      // Set up signal handling for graceful shutdown
      _setupSignalHandling(server);
      
      // Start server in insecure mode (ignoring TLS for now)
      _logger.info("Starting server in insecure mode");
      await server.serve(
        address: '0.0.0.0',
        port: serverPort,
      );
      
      _logger.info("Server listening on port ${server.port}...");
      _logger.info("Version: ${Utils.getVersion()}");
      
    } catch (e, stackTrace) {
      _logger.severe("Server failed to start: $e");
      _logger.fine("Stack trace: $stackTrace");
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
    Logger.root.onRecord.listen((LogRecord rec) {
      // Print to console
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
      
      // Write to log file
      outputFile.writeAsStringSync(
        "${rec.time} | ${rec.level} | ${rec.message}\n",
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
    
    // Handle SIGTERM
    ProcessSignal.sigterm.watch().listen((_) {
      _logger.info('Received SIGTERM signal, shutting down server...');
      server.shutdown().then((_) {
        _logger.info('Server shutdown complete');
        exit(0);
      });
    });
  }
}

/// Implementation of the gRPC LandingService
class LandingService extends LandingServiceBase {
  /// Logger instance
  final Logger logger;
  
  /// Backend client for proxy mode (not implemented in this version)
  // final LandingServiceClient? _backendClient;
  
  /// Constructor
  LandingService({required this.logger});
  
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
    } catch (e) {
      // Default to first greeting on parsing error
      index = 0;
    }
    
    // Get the greeting for this index
    final String hello = greetings[index];
    
    // Create key-value map for response
    final Map<String, String> kv = {
      'id': Utils.getUuid(),
      'idx': id,
      'data': '$hello,${translations[hello]!}',
      'meta': 'DART'
    };
    
    // Create result
    final result = TalkResult()
      ..id = Utils.timestamp()
      ..type = ResultType.OK;
    
    result.kv.addAll(kv);
    return result;
  }
  
  /// Implements the unary RPC method
  @override
  Future<TalkResponse> talk(grpc.ServiceCall call, TalkRequest request) async {
    logMetadata("Talk", call);
    
    logger.info("Unary call received - data: ${request.data}, meta: ${request.meta}");
    
    // Create response
    final response = TalkResponse()..status = 200;
    response.results.add(createResponse(request.data));
    
    return response;
  }
  
  /// Implements the server streaming RPC method
  @override
  Stream<TalkResponse> talkOneAnswerMore(
      grpc.ServiceCall call, TalkRequest request) async* {
    logMetadata("TalkOneAnswerMore", call);
    
    logger.info("Server streaming call received - data: ${request.data}, meta: ${request.meta}");
    
    // Split input data by comma
    final List<String> items = request.data.split(",");
    
    // Generate a response for each item
    for (String item in items) {
      final response = TalkResponse()..status = 200;
      response.results.add(createResponse(item));
      yield response;
    }
  }
  
  /// Implements the client streaming RPC method
  @override
  Future<TalkResponse> talkMoreAnswerOne(
      grpc.ServiceCall call, Stream<TalkRequest> requests) async {
    logMetadata("TalkMoreAnswerOne", call);
    
    logger.info("Client streaming call received");
    
    // Create response
    final response = TalkResponse()..status = 200;
    
    // Process all incoming requests
    await for (final request in requests) {
      logger.info("Client stream item - data: ${request.data}, meta: ${request.meta}");
      response.results.add(createResponse(request.data));
    }
    
    return response;
  }
  
  /// Implements the bidirectional streaming RPC method
  @override
  Stream<TalkResponse> talkBidirectional(
      grpc.ServiceCall call, Stream<TalkRequest> requests) async* {
    logMetadata("TalkBidirectional", call);
    
    logger.info("Bidirectional streaming call received");
    
    // Process each request and yield a response
    await for (final request in requests) {
      logger.info("Bidirectional stream item - data: ${request.data}, meta: ${request.meta}");
      
      final response = TalkResponse()..status = 200;
      response.results.add(createResponse(request.data));
      yield response;
    }
  }
  
  /// Log request metadata for debugging
  /// 
  /// [methodName] Name of the RPC method
  /// [call] The service call containing metadata
  void logMetadata(String methodName, grpc.ServiceCall call) {
    final clientMetadata = call.clientMetadata;
    
    if (clientMetadata == null || clientMetadata.isEmpty) {
      logger.info("$methodName - No metadata present");
      return;
    }
    
    for (final entry in clientMetadata.entries) {
      logger.info("$methodName - header: ${entry.key}: ${entry.value}");
    }
  }
}
