import 'dart:io';
import 'dart:io' as io show Platform;

import 'package:grpc/grpc.dart' as grpc;
import 'package:logger/logger.dart';

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'common/log.dart';

late Logger logger;

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

class Server {
  Future<void> main(List<String> args) async {
    var file = File('./hello.log');
    logger = HelloLog(file).buildLogger();
    var user = envVars['USER'];
    logger.i("User:$user");
    final server = grpc.Server.create(services: [LandingService()]);
    await server.serve(port: 8080);
    logger.i("Server listening on port ${server.port}...");
  }
}

class LandingService extends LandingServiceBase {
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
    var response = TalkResponse()..status = 200;
    response.results.add(buildResult(request.data));
    return response;
  }

  @override
  Stream<TalkResponse> talkBidirectional(
      grpc.ServiceCall call, Stream<TalkRequest> request) {
    // TODO: implement talkBidirectional
    throw UnimplementedError();
  }

  @override
  Future<TalkResponse> talkMoreAnswerOne(
      grpc.ServiceCall call, Stream<TalkRequest> request) {
    // TODO: implement talkMoreAnswerOne
    throw UnimplementedError();
  }

  @override
  Stream<TalkResponse> talkOneAnswerMore(
      grpc.ServiceCall call, TalkRequest request) {
    // TODO: implement talkOneAnswerMore
    throw UnimplementedError();
  }
}
