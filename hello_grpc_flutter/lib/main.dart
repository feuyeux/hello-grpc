import 'dart:math';

import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'conn/conn.dart';
import 'package:grpc/grpc.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Conn.initializeWithLocalIP();
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
  late final TextEditingController hostController;
  late final TextEditingController portController;
  
  HelloAppState() {
    hostController = TextEditingController(text: Conn.host);
    portController = TextEditingController(text: Conn.port.toString());
  }
  void updateConnection() {
    final host = hostController.text.trim();
    final portText = portController.text.trim();
    
    if (host.isNotEmpty && portText.isNotEmpty) {
      try {
        final port = int.parse(portText);
        Conn.updateConnection(host, port);
        notifyListeners();
      } catch (e) {
        // Handle invalid port number
      }
    }
  }

  Future<void> askRPC() async {
    updateConnection();
    
    DateTime dateTime = DateTime.now();
    list.clear();
    list.add("host:${Conn.host},port:${Conn.port}");
    list.add("==BEGIN(${dateTime.toString().substring(2, 19)})==");

    // 移除了定位服务代码，专注于gRPC通信演示

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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'gRPC Server Configuration',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: appState.hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            hintText: 'localhost',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: appState.portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '9996',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current: ${Conn.host}:${Conn.port}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
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
