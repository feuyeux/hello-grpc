import 'package:hello_grpc_dart/common/utils.dart';

void main() async {
  // 测试异步版本
  final asyncVersion = await Utils.getVersion();
  print('Async version: $asyncVersion');
  
  // 测试同步版本
  final syncVersion = Utils.getVersionSync();
  print('Sync version: $syncVersion');
}