import 'dart:io';
import 'dart:math';
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
      request = TalkRequest()
        ..data = Utils.randomId(5) +
            "," +
            Utils.randomId(5) +
            "," +
            Utils.randomId(5)
        ..meta = "DART";
      await talkOneAnswerMore(request);
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

  Future<void> talkOneAnswerMore(TalkRequest request) async {
    await for (var response in stub.talkOneAnswerMore(request)) {
      logger.i(response);
    }
  }

  Future<void> talkMoreAnswerOne() async {
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

    final response = await stub.talkMoreAnswerOne(generateRequest(3));
    logger.i(response);
  }

  Future<void> talkBidirectional() async {
    Stream<TalkRequest> generateRequests() async* {
      for (var i = 0; i < 3; i++) {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "DART";
        // Short delay to simulate some other interaction.
        await Future.delayed(Duration(milliseconds: 10));
        logger.i('Sending message {data:${request.data}, meta:${request.meta}}');
        yield request;
      }
    }
    final call = stub.talkBidirectional(generateRequests());
    await for (var response in call) {
      logger.i(response);
      ;
    }
  }
}
