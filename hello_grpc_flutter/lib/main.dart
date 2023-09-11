import 'dart:math';

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'conn/conn.dart';
import 'package:grpc/grpc.dart';
import 'package:location/location.dart';

void main() {
  runApp(const HelloApp());
}

class HelloApp extends StatelessWidget {
  const HelloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HelloAppState(),
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromRGBO(0, 255, 0, 1.0)),
          useMaterial3: true,
        ),
        home: const AsksPage(),
      ),
    );
  }
}

class HelloAppState extends ChangeNotifier {
  var list = <String>[];
  Future<void> askRPC() async {
    list.clear();
    list.add("====BEGIN====");

    Location location = Location();
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (serviceEnabled) {
        permissionGranted = await location.hasPermission();
        if (permissionGranted == PermissionStatus.denied) {
          permissionGranted = await location.requestPermission();
          if (permissionGranted == PermissionStatus.granted) {
            locationData = await location.getLocation();
            list.add(locationData.toString());
          }
        } else {
          locationData = await location.getLocation();
          list.add(locationData.toString());
        }
      }
    }

    final channel = ClientChannel(Conn.host,
        port: Conn.port,
        options:
            const ChannelOptions(credentials: ChannelCredentials.insecure()));
    stub = LandingServiceClient(channel,
        options: CallOptions(timeout: const Duration(seconds: 30)));
    // Run all of the demos in order.
    try {
      TalkRequest request = TalkRequest()
        ..data = Utils.randomId(5)
        ..meta = "FLUTTER";
      await talk(request);
      request = TalkRequest()
        ..data =
            "${Utils.randomId(5)},${Utils.randomId(5)},${Utils.randomId(5)}"
        ..meta = "FLUTTER";
      await talkOneAnswerMore(request);
      await talkMoreAnswerOne();
      await talkBidirectional();
    } catch (e) {
      // ignore: avoid_print
      print('Caught error: $e');
    }
    await channel.shutdown();
    list.add("====END====");
    notifyListeners();
  }

  Future<TalkResponse> talk(TalkRequest request) async {
    final response = await stub.talk(request);
    list.add("Request/Response");
    list.add(response.toString());
    return response;
  }

  Future<void> talkOneAnswerMore(TalkRequest request) async {
    await for (var response in stub.talkOneAnswerMore(request)) {
      list.add("Server Streaming");
      list.add(response.toString());
    }
  }

  Future<void> talkMoreAnswerOne() async {
    Stream<TalkRequest> generateRequest(int count) async* {
      final random = Random();
      for (var i = 0; i < count; i++) {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "FLUTTER";
        yield request;
        await Future.delayed(Duration(milliseconds: 100 + random.nextInt(100)));
      }
    }

    final response = await stub.talkMoreAnswerOne(generateRequest(3));
    list.add("Client Streaming");
    list.add(response.toString());
  }

  Future<void> talkBidirectional() async {
    Stream<TalkRequest> generateRequests() async* {
      for (var i = 0; i < 3; i++) {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "FLUTTER";
        // Short delay to simulate some other interaction.
        await Future.delayed(const Duration(milliseconds: 10));
        yield request;
      }
    }

    final call = stub.talkBidirectional(generateRequests());
    await for (var response in call) {
      list.add("Bidirectional Streaming");
      list.add(response.toString());
    }
  }
}

late LandingServiceClient stub;

class AsksPage extends StatelessWidget {
  const AsksPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<HelloAppState>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton(
                onPressed: () {
                  appState.askRPC();
                },
                child: const Text('ASK gRPC Server From Flutter'),
              ),
            ],
          ),
          const Padding(padding: EdgeInsets.all(20)),
          for (var response in appState.list)
            Card(
              child: ListTile(
                title: Text(response.toString()),
              ),
            ),
        ],
      ),
    );
  }
}
