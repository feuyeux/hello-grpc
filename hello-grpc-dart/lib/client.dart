import 'dart:io';
import 'dart:io' as io show Platform;
import 'dart:math';
import 'package:grpc/grpc.dart';
import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'package:logging/logging.dart';

import 'conn/conn.dart';

var outputFile = new File('hello_client.log');

Map<String, String> envVars = io.Platform.environment;

class Client {
  late LandingServiceClient stub;
  late Logger logger;

  Future<void> main(List<String> args) async {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
      outputFile.writeAsStringSync(
          "${rec.time} | ${rec.level} | ${rec.message}\n",
          mode: FileMode.append);
    });
    logger = new Logger('HelloClient');
    String? GRPC_SERVER = envVars['GRPC_SERVER'];
    String connectTo = GRPC_SERVER ?? "127.0.0.1";
    logger.info("GRPC_SERVER:${connectTo}");
    
    // Configure channel with TLS if enabled
    final ChannelCredentials credentials;
    if (Conn.isSecure) {
      logger.info("Using secure connection (TLS)");
      logger.info("Root cert path: ${Conn.rootCertPath}");
      
      // Read root certificate
      final rootCert = await File(Conn.rootCertPath).readAsBytes();
      credentials = ChannelCredentials.secure(
        certificates: rootCert,
        authority: 'hello.grpc.io',
      );
    } else {
      logger.info("Using insecure connection");
      credentials = ChannelCredentials.insecure();
    }
    
    final channel = ClientChannel(connectTo,
        port: Conn.getServerPort(),
        options: ChannelOptions(credentials: credentials));
    stub = LandingServiceClient(channel,
        options: CallOptions(timeout: Duration(seconds: 30)));
    // Run all of the demos in order.
    try {
      TalkRequest request = TalkRequest()
        ..data = Utils.randomId(5)
        ..meta = "DART";
      Map<String, String> metadata = Map();
      metadata["k1"] = "v1";
      metadata["k2"] = "v2";
      await talk(request, metadata);
      request = TalkRequest()
        ..data = Utils.randomId(5) +
            "," +
            Utils.randomId(5) +
            "," +
            Utils.randomId(5)
        ..meta = "DART";
      await talkOneAnswerMore(request, metadata);
      await talkMoreAnswerOne(metadata);
      await talkBidirectional(metadata);
    } catch (e) {
      print('Caught error: $e');
    }
    await channel.shutdown();
  }

  void doSleep(int sec) {
    var duration = Duration(seconds: sec);
    print('Start sleeping');
    sleep(duration);
    print('5 seconds has passed');
  }

  Future<TalkResponse> talk(
      TalkRequest request, Map<String, String> metadata) async {
    var callOptions = CallOptions(metadata: metadata);
    final response = await stub.talk(request, options: callOptions);
    logger.info(response);
    return response;
  }

  Future<void> talkOneAnswerMore(
      TalkRequest request, Map<String, String> metadata) async {
    var callOptions = CallOptions(metadata: metadata);
    await for (var response
        in stub.talkOneAnswerMore(request, options: callOptions)) {
      logger.info(response);
    }
  }

  Future<void> talkMoreAnswerOne(Map<String, String> metadata) async {
    var callOptions = CallOptions(metadata: metadata);
    Stream<TalkRequest> generateRequest(int count) async* {
      final random = Random();
      for (var i = 0; i < count; i++) {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "DART";
        yield request;
        await Future.delayed(Duration(milliseconds: 100 + random.nextInt(100)));
      }
    }

    final response =
        await stub.talkMoreAnswerOne(generateRequest(3), options: callOptions);
    logger.info(response);
  }

  Future<void> talkBidirectional(Map<String, String> metadata) async {
    var callOptions = CallOptions(metadata: metadata);
    Stream<TalkRequest> generateRequests() async* {
      for (var i = 0; i < 3; i++) {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "DART";
        // Short delay to simulate some other interaction.
        await Future.delayed(Duration(milliseconds: 10));
        logger.info(
            'Sending message {data:${request.data}, meta:${request.meta}}');
        yield request;
      }
    }

    final call =
        stub.talkBidirectional(generateRequests(), options: callOptions);
    await for (var response in call) {
      logger.info(response);
    }
  }
}
