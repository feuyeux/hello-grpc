import 'package:hello_grpc_dart/common/utils.dart';
import 'package:logging/logging.dart';

void main() async {
  final logger = Logger('VersionTest');

  // Test async version
  final asyncVersion = await Utils.getVersion();
  logger.info('Async version: $asyncVersion');

  // Test sync version
  final syncVersion = Utils.getVersionSync();
  logger.info('Sync version: $syncVersion');
}
