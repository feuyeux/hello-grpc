import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common/common.dart';
import 'common/landing.pbgrpc.dart';
import 'package:provider/provider.dart';
import 'conn/conn.dart';
import 'conn/web_grpc_client.dart';
import 'package:grpc/grpc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await Conn.initializeWithLocalIP();
  }
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
            seedColor: const Color.fromRGBO(129, 199, 132, 1.0), // #81c784
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color.fromRGBO(
            18,
            18,
            18,
            1.0,
          ), // #121212
          cardTheme: CardThemeData(
            color: const Color.fromRGBO(30, 30, 30, 1.0), // #1e1e1e
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(
                129,
                199,
                132,
                1.0,
              ), // #81c784
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              minimumSize: const Size(0, 48),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
  String systemInfo = '';

  HelloAppState() {
    hostController = TextEditingController(text: Conn.host);
    portController = TextEditingController(text: Conn.port.toString());
    _getSystemInfo();

    // 添加输入监听来实时更新显示
    hostController.addListener(_updateDisplay);
    portController.addListener(_updateDisplay);
  }

  void _updateDisplay() {
    notifyListeners(); // 触发UI更新
  }

  String get currentConfig {
    final host = hostController.text.trim().isEmpty
        ? 'localhost'
        : hostController.text.trim();
    final port = portController.text.trim().isEmpty
        ? '9996'
        : portController.text.trim();
    return '$host:$port';
  }

  void _getSystemInfo() {
    if (kIsWeb) {
      systemInfo = 'Web';
    } else {
      // 对于非Web平台，需要导入dart:io
      systemInfo = 'Flutter';
    }
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

    if (kIsWeb) {
      // Web平台使用HTTP客户端模拟
      list.add("Web Platform - Using HTTP simulation for gRPC");
      final webClient = WebGrpcClient(Conn.host, Conn.port);

      try {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "FLUTTER_WEB";
        await talkWeb(webClient, request);

        request = TalkRequest()
          ..data =
              "${Utils.randomId(5)},${Utils.randomId(5)},${Utils.randomId(5)}"
          ..meta = "FLUTTER_WEB";
        await talkOneAnswerMoreWeb(webClient, request);
        await talkMoreAnswerOneWeb(webClient);
        await talkBidirectionalWeb(webClient);
      } catch (e) {
        list.add('Web Error: $e');
        print('Caught web error: $e');
      }
    } else {
      // 非Web平台的真实gRPC调用
      final channel = ClientChannel(
        Conn.host,
        port: Conn.port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
      stub = LandingServiceClient(
        channel,
        options: CallOptions(timeout: const Duration(seconds: 30)),
      );
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
        list.add("Error: $e");
      }
      await channel.shutdown();
    }
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

  // Web平台的gRPC方法
  Future<TalkResponse> talkWeb(
    WebGrpcClient client,
    TalkRequest request,
  ) async {
    final response = await client.talk(request);
    list.add("Web Request/Response");
    list.add(response.toString());
    return response;
  }

  Future<void> talkOneAnswerMoreWeb(
    WebGrpcClient client,
    TalkRequest request,
  ) async {
    try {
      final stream = client.talkOneAnswerMore(request);
      await for (var response in stream) {
        list.add("Web Server Streaming");
        list.add(response.toString());
      }
    } catch (e) {
      list.add("Web Error: $e");
    }
  }

  Future<void> talkMoreAnswerOneWeb(WebGrpcClient client) async {
    Stream<TalkRequest> generateRequest(int count) async* {
      final random = Random();
      for (var i = 0; i < count; i++) {
        TalkRequest request = TalkRequest()
          ..data = Utils.randomId(5)
          ..meta = "FLUTTER_WEB";
        yield request;
        await Future.delayed(Duration(milliseconds: 100 + random.nextInt(100)));
      }
    }

    final response = await client.talkMoreAnswerOne(generateRequest(3));
    list.add("Web Client Streaming");
    list.add(response.toString());
  }

  Future<void> talkBidirectionalWeb(WebGrpcClient client) async {
    try {
      Stream<TalkRequest> generateRequests() async* {
        for (var i = 0; i < 3; i++) {
          TalkRequest request = TalkRequest()
            ..data = Utils.randomId(5)
            ..meta = "FLUTTER_WEB";
          await Future.delayed(const Duration(milliseconds: 10));
          yield request;
        }
      }

      final stream = generateRequests();
      await for (var response in client.talkBidirectional(stream)) {
        list.add("Web Bidirectional Streaming");
        list.add(response.toString());
      }
    } catch (e) {
      list.add("Web Error: $e");
    }
  }
}

late LandingServiceClient stub;

class AsksPage extends StatelessWidget {
  const AsksPage({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<HelloAppState>();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(18, 18, 18, 1.0), // #121212
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 修改为可折行的布局
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'gRPC Server Configuration --  ${appState.systemInfo}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Current: ${appState.currentConfig}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 在小屏幕设备上使用垂直布局
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // 如果宽度小于600，使用垂直布局
                          if (constraints.maxWidth < 600) {
                            return Column(
                              children: [
                                SizedBox(
                                  height: 56,
                                  child: TextField(
                                    controller: appState.hostController,
                                    decoration: const InputDecoration(
                                      labelText: 'Host',
                                      hintText: 'localhost',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      labelStyle: TextStyle(
                                        color: Color.fromRGBO(
                                          129,
                                          199,
                                          132,
                                          1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color.fromRGBO(
                                            129,
                                            199,
                                            132,
                                            1.0,
                                          ),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 56,
                                  child: TextField(
                                    controller: appState.portController,
                                    decoration: const InputDecoration(
                                      labelText: 'Port',
                                      hintText: '9996',
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      labelStyle: TextStyle(
                                        color: Color.fromRGBO(
                                          129,
                                          199,
                                          132,
                                          1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Color.fromRGBO(
                                            129,
                                            199,
                                            132,
                                            1.0,
                                          ),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // 宽屏设备使用水平布局
                            return Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 56,
                                    child: TextField(
                                      controller: appState.hostController,
                                      decoration: const InputDecoration(
                                        labelText: 'Host',
                                        hintText: 'localhost',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        labelStyle: TextStyle(
                                          color: Color.fromRGBO(
                                            129,
                                            199,
                                            132,
                                            1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color.fromRGBO(
                                              129,
                                              199,
                                              132,
                                              1.0,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: 56,
                                    child: TextField(
                                      controller: appState.portController,
                                      decoration: const InputDecoration(
                                        labelText: 'Port',
                                        hintText: '9996',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        labelStyle: TextStyle(
                                          color: Color.fromRGBO(
                                            129,
                                            199,
                                            132,
                                            1.0,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color.fromRGBO(
                                              129,
                                              199,
                                              132,
                                              1.0,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    appState.askRPC();
                  },
                  child: const Text('ASK gRPC Server From Flutter'),
                ),
              ),
              const SizedBox(height: 20),
              for (var response in appState.list)
                Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ListTile(
                    title: Text(
                      response.toString(),
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
