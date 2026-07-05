import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:io' as io show Platform;

import 'package:grpc/grpc.dart' as grpc;
import 'package:grpc/service_api.dart' as grpc_api;
import 'package:logging/logging.dart';

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'common/otel.dart';
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

/// B7 — gRPC Health Check (grpc.health.v1.Health/Check)
///
/// Implements the standard gRPC health-checking protocol without any extra
/// package dependency. The grpc ^4.x package does not ship a built-in
/// HealthService, so the wire format is handled manually:
///
///   HealthCheckRequest  field 1 = string service  (tag 0x0a)
///   HealthCheckResponse field 1 = enum   status   (tag 0x08)
///     ServingStatus: UNKNOWN=0, SERVING=1, NOT_SERVING=2
///
/// This server always returns SERVING (1) for every service name, which is
/// the correct behaviour for a healthy, running server.
class HealthCheckService extends grpc_api.Service {
  @override
  String get $name => 'grpc.health.v1.Health';

  HealthCheckService() {
    $addMethod(
      grpc_api.ServiceMethod<List<int>, List<int>>(
        'Check',
        _check,
        false,
        false,
        (List<int> data) => data,
        (List<int> data) => data,
      ),
    );
    $addMethod(
      grpc_api.ServiceMethod<List<int>, List<int>>(
        'Watch',
        _watch,
        false,
        true,
        (List<int> data) => data,
        (List<int> data) => data,
      ),
    );
  }

  /// Encode a HealthCheckResponse with status=SERVING (1).
  ///
  /// Protobuf wire encoding: field 1, type varint → tag byte 0x08, value 0x01.
  static final List<int> _servingResponse = [0x08, 0x01];

  Future<List<int>> _check(
    grpc.ServiceCall call,
    Future<List<int>> request,
  ) async {
    // Consume the request (we don't need the service-name field here).
    await request;
    return _servingResponse;
  }

  Stream<List<int>> _watch(
    grpc.ServiceCall call,
    Future<List<int>> request,
  ) async* {
    await request;
    // Emit one SERVING response and keep the stream open until the client
    // cancels — this satisfies the Watch contract for a perpetually-serving
    // server without requiring a full pub/sub mechanism.
    yield _servingResponse;
    await Future<void>.delayed(const Duration(days: 365));
  }
}

/// C4 — gRPC Server Reflection (grpc.reflection.v1alpha.ServerReflection).
///
/// The grpc ^4.x Dart package does not ship a built-in reflection service, so
/// this implementation handles the small v1alpha reflection wire format
/// directly and serves the embedded FileDescriptorProto for landing.proto.
class ReflectionService extends grpc_api.Service {
  @override
  String get $name => 'grpc.reflection.v1alpha.ServerReflection';

  static final List<int> _landingFileDescriptorProto = base64Decode(
    'Cg1sYW5kaW5nLnByb3RvEgVoZWxsbyI1CgtUYWxrUmVxdWVzdBISCgRkYXRhGAEgASgJUgRkYXRhEhIKBG1ldGEYAiABKAlSBG1ldGEiUwoMVGFsa1Jlc3BvbnNlEhYKBnN0YXR1cxgBIAEoBVIGc3RhdHVzEisKB3Jlc3VsdHMYAiADKAsyES5oZWxsby5UYWxrUmVzdWx0UgdyZXN1bHRzIqUBCgpUYWxrUmVzdWx0Eg4KAmlkGAEgASgDUgJpZBIlCgR0eXBlGAIgASgOMhEuaGVsbG8uUmVzdWx0VHlwZVIEdHlwZRIpCgJrdhgDIAMoCzIZLmhlbGxvLlRhbGtSZXN1bHQuS3ZFbnRyeVICa3YaNQoHS3ZFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgBKh4KClJlc3VsdFR5cGUSBgoCT0sQABIICgRGQUlMEAEyiwIKDkxhbmRpbmdTZXJ2aWNlEjEKBFRhbGsSEi5oZWxsby5UYWxrUmVxdWVzdBoTLmhlbGxvLlRhbGtSZXNwb25zZSIAEkAKEVRhbGtPbmVBbnN3ZXJNb3JlEhIuaGVsbG8uVGFsa1JlcXVlc3QaEy5oZWxsby5UYWxrUmVzcG9uc2UiADABEkAKEVRhbGtNb3JlQW5zd2VyT25lEhIuaGVsbG8uVGFsa1JlcXVlc3QaEy5oZWxsby5UYWxrUmVzcG9uc2UiACgBEkIKEVRhbGtCaWRpcmVjdGlvbmFsEhIuaGVsbG8uVGFsa1JlcXVlc3QaEy5oZWxsby5UYWxrUmVzcG9uc2UiACgBMAFCLgoWb3JnLmZldXlldXguZ3JwYy5wcm90b0IHTGFuZGluZ1ABWgljb21tb24vcGJiBnByb3RvMw==',
  );

  static const List<String> _serviceNames = [
    'hello.LandingService',
    'grpc.health.v1.Health',
    'grpc.reflection.v1alpha.ServerReflection',
  ];

  ReflectionService() {
    $addMethod(
      grpc_api.ServiceMethod<List<int>, List<int>>(
        'ServerReflectionInfo',
        _serverReflectionInfo,
        true,
        true,
        (List<int> data) => data,
        (List<int> data) => data,
      ),
    );
  }

  Stream<List<int>> _serverReflectionInfo(
    grpc.ServiceCall call,
    Stream<List<int>> requests,
  ) async* {
    await for (final requestBytes in requests) {
      final request = _ReflectionRequest.decode(requestBytes);
      if (request.listServices != null) {
        yield _response(
          requestBytes,
          fieldNumber: 6,
          payload: _listServicesResponse(_serviceNames),
        );
      } else if (_matchesLandingFile(request.fileByFilename)) {
        yield _fileDescriptorResponse(requestBytes);
      } else if (_matchesLandingSymbol(request.fileContainingSymbol)) {
        yield _fileDescriptorResponse(requestBytes);
      } else {
        yield _response(
          requestBytes,
          fieldNumber: 7,
          payload: _errorResponse(
            5,
            'Symbol or file is not available from this Dart server',
          ),
        );
      }
    }
  }

  static bool _matchesLandingFile(String? fileName) {
    return fileName == 'landing.proto' || fileName == 'proto/landing.proto';
  }

  static bool _matchesLandingSymbol(String? symbol) {
    if (symbol == null || symbol.isEmpty) return false;
    return symbol == 'hello' ||
        symbol == 'hello.LandingService' ||
        symbol.startsWith('hello.LandingService.') ||
        symbol == 'hello.TalkRequest' ||
        symbol == 'hello.TalkResponse' ||
        symbol == 'hello.TalkResult' ||
        symbol == 'hello.ResultType';
  }

  static List<int> _fileDescriptorResponse(List<int> originalRequest) {
    final fileDescriptorResponse = _bytesField(1, _landingFileDescriptorProto);
    return _response(
      originalRequest,
      fieldNumber: 4,
      payload: fileDescriptorResponse,
    );
  }

  static List<int> _response(
    List<int> originalRequest, {
    required int fieldNumber,
    required List<int> payload,
  }) {
    return [
      ..._stringField(1, ''),
      ..._bytesField(2, originalRequest),
      ..._bytesField(fieldNumber, payload),
    ];
  }

  static List<int> _listServicesResponse(List<String> serviceNames) {
    return [
      for (final serviceName in serviceNames)
        ..._bytesField(1, _stringField(1, serviceName)),
    ];
  }

  static List<int> _errorResponse(int code, String message) {
    return [..._varintField(1, code), ..._stringField(2, message)];
  }
}

class _ReflectionRequest {
  _ReflectionRequest({
    required this.fileByFilename,
    required this.fileContainingSymbol,
    required this.listServices,
  });

  final String? fileByFilename;
  final String? fileContainingSymbol;
  final String? listServices;

  static _ReflectionRequest decode(List<int> data) {
    var pos = 0;
    String? fileByFilename;
    String? fileContainingSymbol;
    String? listServices;

    while (pos < data.length) {
      final tag = _readVarint(data, pos);
      pos = tag.next;
      final fieldNumber = tag.value >> 3;
      final wireType = tag.value & 0x07;

      if (wireType == 2) {
        final length = _readVarint(data, pos);
        pos = length.next;
        final end = pos + length.value;
        final value = utf8.decode(data.sublist(pos, end));
        pos = end;

        if (fieldNumber == 3) {
          fileByFilename = value;
        } else if (fieldNumber == 4) {
          fileContainingSymbol = value;
        } else if (fieldNumber == 7) {
          listServices = value;
        }
      } else {
        pos = _skipField(data, pos, wireType);
      }
    }

    return _ReflectionRequest(
      fileByFilename: fileByFilename,
      fileContainingSymbol: fileContainingSymbol,
      listServices: listServices,
    );
  }
}

class _VarintResult {
  const _VarintResult(this.value, this.next);

  final int value;
  final int next;
}

_VarintResult _readVarint(List<int> data, int pos) {
  var value = 0;
  var shift = 0;
  while (pos < data.length) {
    final byte = data[pos++];
    value |= (byte & 0x7f) << shift;
    if ((byte & 0x80) == 0) {
      return _VarintResult(value, pos);
    }
    shift += 7;
  }
  throw grpc.GrpcError.invalidArgument('Malformed reflection request');
}

int _skipField(List<int> data, int pos, int wireType) {
  if (wireType == 0) {
    return _readVarint(data, pos).next;
  }
  if (wireType == 1) {
    return pos + 8;
  }
  if (wireType == 2) {
    final length = _readVarint(data, pos);
    return length.next + length.value;
  }
  if (wireType == 5) {
    return pos + 4;
  }
  throw grpc.GrpcError.invalidArgument(
    'Unsupported reflection request wire type: $wireType',
  );
}

List<int> _varint(int value) {
  final out = <int>[];
  var current = value;
  while (current > 0x7f) {
    out.add((current & 0x7f) | 0x80);
    current >>= 7;
  }
  out.add(current);
  return out;
}

List<int> _tag(int fieldNumber, int wireType) {
  return _varint((fieldNumber << 3) | wireType);
}

List<int> _varintField(int fieldNumber, int value) {
  return [..._tag(fieldNumber, 0), ..._varint(value)];
}

List<int> _bytesField(int fieldNumber, List<int> value) {
  return [..._tag(fieldNumber, 2), ..._varint(value.length), ...value];
}

List<int> _stringField(int fieldNumber, String value) {
  return _bytesField(fieldNumber, utf8.encode(value));
}

/// Main server class that initializes and manages the gRPC server
class Server {
  /// Logger instance for this class
  late final Logger _logger;

  /// Path to the log file
  final String _logFile = 'hello_server.log';

  /// Main entry point for the server
  Future<void> main(List<String> args) async {
    // Initialize OpenTelemetry when GRPC_HELLO_OTEL=Y, before any
    // grpc.Server() is constructed so a configured global tracer is
    // available for any subsequent handler-side span emission.
    await initOtel('hello-grpc-dart-server');
    initMetrics('hello-grpc-dart-server');

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

      // Create backend client if in proxy mode
      LandingServiceClient? backendClient;
      if (Conn.hasBackend) {
        _logger.info('Proxy mode enabled - initializing backend client');
        final backendHost = Conn.backendHost!;
        final backendPortStr =
            io.Platform.environment['GRPC_HELLO_BACKEND_PORT'];
        final backendPort =
            backendPortStr != null ? int.parse(backendPortStr) : 9996;

        _logger.info('Connecting to backend at $backendHost:$backendPort');

        final backendChannel = grpc.ClientChannel(
          backendHost,
          port: backendPort,
          options: grpc.ChannelOptions(
            credentials:
                Conn.isSecure
                    ? grpc.ChannelCredentials.secure(
                      certificates: await File(Conn.rootCertPath).readAsBytes(),
                    )
                    : const grpc.ChannelCredentials.insecure(),
            // Client-side HTTP/2 keepalive for the proxy backend channel.
            keepAlive: const grpc.ClientKeepAliveOptions(
              pingInterval: Duration(seconds: 10),
              timeout: Duration(seconds: 1),
              permitWithoutCalls: true,
            ),
            // Advertise gzip + identity so the backend can accept
            // compressed responses when it supports them.
            codecRegistry: grpc.CodecRegistry(
              codecs: [grpc.IdentityCodec(), grpc.GzipCodec()],
            ),
          ),
        );

        backendClient = LandingServiceClient(backendChannel);
        _logger.info('Backend client initialized');
      }

      // Create server with service implementation
      final server = grpc.Server.create(
        services: [
          LandingService(logger: _logger, backendClient: backendClient),
          // B7: gRPC health check — grpc.health.v1.Health
          HealthCheckService(),
          // C4: gRPC server reflection stub — grpc.reflection.v1alpha.ServerReflection
          ReflectionService(),
        ],
        serverInterceptors: [serverInterceptor],
        // Enable gzip decompression so cross-language clients (e.g. Java)
        // that send grpc-encoding: gzip are handled transparently.
        codecRegistry: grpc.CodecRegistry(
          codecs: [grpc.IdentityCodec(), grpc.GzipCodec()],
        ),
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
      // Log to console using print to avoid recursion
      // ignore: avoid_print
      print('${rec.level.name}: ${rec.time}: ${rec.message}');

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
  LandingService({required this.logger, this.backendClient});

  /// Logger instance
  final Logger logger;

  /// Backend client for proxy mode
  final LandingServiceClient? backendClient;

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
    recordRpcCall('Talk');
    final requestId = 'unary-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('Talk', call, requestId);

    logger.info(
      'REQUEST: method=Talk, request_id=$requestId, data=${request.data}, meta=${request.meta}',
    );

    try {
      // Forward to backend if in proxy mode
      if (backendClient != null) {
        logger.info('Forwarding request to backend: request_id=$requestId');
        final startTime = DateTime.now();

        // Forward metadata/headers
        final metadata = _extractTracingHeaders(call);
        final response = await backendClient!.talk(
          request,
          options: grpc.CallOptions(metadata: metadata),
        );

        final duration = DateTime.now().difference(startTime);
        logger.info(
          'Backend response received: request_id=$requestId, duration=${duration.inMilliseconds}ms',
        );
        return response;
      }

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
    recordRpcCall('TalkOneAnswerMore');
    final requestId = 'server-stream-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('TalkOneAnswerMore', call, requestId);

    logger.info(
      'REQUEST: method=TalkOneAnswerMore, request_id=$requestId, data=${request.data}, meta=${request.meta}',
    );

    try {
      // Forward to backend if in proxy mode
      if (backendClient != null) {
        logger.info(
          'Forwarding server streaming request to backend: request_id=$requestId',
        );
        final startTime = DateTime.now();

        // Forward metadata/headers
        final metadata = _extractTracingHeaders(call);
        final responseStream = backendClient!.talkOneAnswerMore(
          request,
          options: grpc.CallOptions(metadata: metadata),
        );

        var count = 0;
        await for (final response in responseStream) {
          count++;
          logger.info(
            'Forwarding response #$count from backend: request_id=$requestId',
          );
          yield response;
        }

        final duration = DateTime.now().difference(startTime);
        logger.info(
          'Backend streaming completed: request_id=$requestId, responses=$count, duration=${duration.inMilliseconds}ms',
        );
        return;
      }

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
    recordRpcCall('TalkMoreAnswerOne');
    final requestId = 'client-stream-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('TalkMoreAnswerOne', call, requestId);

    logger.info('REQUEST: method=TalkMoreAnswerOne, request_id=$requestId');

    try {
      // Forward to backend if in proxy mode
      if (backendClient != null) {
        logger.info(
          'Forwarding client streaming request to backend: request_id=$requestId',
        );
        final startTime = DateTime.now();

        // Forward metadata/headers
        final metadata = _extractTracingHeaders(call);
        final response = await backendClient!.talkMoreAnswerOne(
          requests,
          options: grpc.CallOptions(metadata: metadata),
        );

        final duration = DateTime.now().difference(startTime);
        logger.info(
          'Backend response received: request_id=$requestId, duration=${duration.inMilliseconds}ms',
        );
        return response;
      }

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
    recordRpcCall('TalkBidirectional');
    final requestId = 'bidirectional-${DateTime.now().millisecondsSinceEpoch}';
    _logMetadata('TalkBidirectional', call, requestId);

    logger.info('REQUEST: method=TalkBidirectional, request_id=$requestId');

    try {
      // Forward to backend if in proxy mode
      if (backendClient != null) {
        logger.info(
          'Forwarding bidirectional streaming request to backend: request_id=$requestId',
        );
        final startTime = DateTime.now();

        // Forward metadata/headers
        final metadata = _extractTracingHeaders(call);
        final responseStream = backendClient!.talkBidirectional(
          requests,
          options: grpc.CallOptions(metadata: metadata),
        );

        var count = 0;
        await for (final response in responseStream) {
          count++;
          logger.info(
            'Forwarding response #$count from backend: request_id=$requestId',
          );
          yield response;
        }

        final duration = DateTime.now().difference(startTime);
        logger.info(
          'Backend bidirectional streaming completed: request_id=$requestId, responses=$count, duration=${duration.inMilliseconds}ms',
        );
        return;
      }

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

  /// Extract tracing headers from incoming request
  ///
  /// [call] The service call containing metadata
  /// Returns a map of tracing headers to forward to backend
  Map<String, String> _extractTracingHeaders(grpc.ServiceCall call) {
    final headers = <String, String>{};
    final clientMetadata = call.clientMetadata;

    if (clientMetadata != null) {
      for (final headerName in tracingHeaders) {
        final value = clientMetadata[headerName];
        if (value != null) {
          headers[headerName] = value;
        }
      }
    }

    return headers;
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
