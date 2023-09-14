import 'dart:io';
import 'dart:io' as io show Platform;

import 'package:grpc/grpc.dart' as grpc;

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';

import 'package:logging/logging.dart';

import 'conn/conn.dart';

const hellos = ["Hello", "Bonjour", "Hola", "こんにちは", "Ciao", "안녕하세요"];

Map<String, String> ans = {
  "你好": "非常感谢",
  "Hello": "Thank you very much",
  "Bonjour": "Merci beaucoup",
  "Hola": "Muchas Gracias",
  "こんにちは": "どうも ありがとう ございます",
  "Ciao": "Mille Grazie",
  "안녕하세요": "대단히 감사합니다"
};

Map<String, String> envVars = io.Platform.environment;
var outputFile = new File('hello_server.log');

class Server {
  Future<void> main(List<String> args) async {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((LogRecord rec) {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
      outputFile.writeAsStringSync(
          "${rec.time} | ${rec.level} | ${rec.message}\n",
          mode: FileMode.append);
    });
    final Logger logger = new Logger('HelloServer');

    var user = envVars['USER'];
    logger.info("User:$user");
    final server =
        grpc.Server.create(services: [LandingService(logger: logger)]);
    await server.serve(port: Conn.port);
    logger.info("Server listening on port ${server.port}...");
  }
}

class LandingService extends LandingServiceBase {
  final Logger logger;

  LandingService({required this.logger});

  // {"status":200,"results":[{"id":1600402320493411000,"kv":{"data":"Hello","id":"0"}}]}
  TalkResult buildResult(String id) {
    var index = int.parse(id);
    var hello = hellos[index];
    var kv = Map<String, String>();
    kv['id'] = Utils.getUuid();
    kv['idx'] = id;
    kv['data'] = hello + "," + ans[hello]!;
    kv['meta'] = 'DART';

    var result = new TalkResult()
      ..id = Utils.timestamp()
      ..type = ResultType.OK;
    result.kv.addAll(kv);
    return result;
  }

  @override
  Future<TalkResponse> talk(grpc.ServiceCall call, TalkRequest request) async {
    readHeaders("talk", call);
    var response = TalkResponse()..status = 200;
    response.results.add(buildResult(request.data));
    return response;
  }

  @override
  Stream<TalkResponse> talkOneAnswerMore(
      grpc.ServiceCall call, TalkRequest request) async* {
    readHeaders("talkOneAnswerMore", call);
    var datas = request.data.split(",");
    for (var data in datas) {
      var response = TalkResponse()..status = 200;
      response.results.add(buildResult(data));
      yield response;
    }
  }

  @override
  Future<TalkResponse> talkMoreAnswerOne(
      grpc.ServiceCall call, Stream<TalkRequest> requests) async {
    readHeaders("talkMoreAnswerOne", call);
    final timer = Stopwatch();
    var response = TalkResponse()..status = 200;
    await for (var request in requests) {
      if (!timer.isRunning) timer.start();
      response.results.add(buildResult(request.data));
    }
    timer.stop();
    return response;
  }

  @override
  Stream<TalkResponse> talkBidirectional(
      grpc.ServiceCall call, Stream<TalkRequest> requests) async* {
    readHeaders("talkBidirectional", call);
    await for (var request in requests) {
      var response = TalkResponse()..status = 200;
      response.results.add(buildResult(request.data));
      yield response;
    }
  }

  void readHeaders(String methodName, grpc.ServiceCall call) {
    var clientMetadata = call.clientMetadata;
    if (clientMetadata != null) {
      var header1 = clientMetadata['k1'];
      var header2 = clientMetadata['k2'];
      logger.info("$methodName headers: k1=$header1,k2=$header2");
    }
  }
}
