import 'package:hello_grpc_dart/server.dart';

Future<void> main(List<String> args) async {
  await Server().main(args);
}
