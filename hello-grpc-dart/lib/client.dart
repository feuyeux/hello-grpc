import 'dart:io';
import 'package:grpc/grpc.dart';
import 'package:logger/logger.dart';
import 'common/common.dart';
import 'common/landing.pbgrpc.dart';

var logger = Logger(
  printer: PrettyPrinter(),
  output: null,
);

class Client {
  late LandingServiceClient stub;

  Future<void> main(List<String> args) async {
    final channel = ClientChannel('127.0.0.1',
        port: 8080,
        options:
            const ChannelOptions(credentials: ChannelCredentials.insecure()));
    stub = LandingServiceClient(channel,
        options: CallOptions(timeout: Duration(seconds: 30)));
    // Run all of the demos in order.
    try {
      TalkRequest request = TalkRequest()
        ..data = Utils.randomId(5)
        ..meta = "DART";
      await talk(request);
      await talkOneAnswerMore();
      await talkMoreAnswerOne();
      await talkBidirectional();
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

  Future<TalkResponse> talk(TalkRequest request) async {
    final response = await stub.talk(request);
    logger.i(response);
    return response;
  }

  Future<void> talkOneAnswerMore() async {

  }

  Future<void> talkMoreAnswerOne() async {}

  Future<void> talkBidirectional() async {}
}
