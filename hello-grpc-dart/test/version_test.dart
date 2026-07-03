import 'package:hello_grpc_dart/common/utils.dart';
import 'package:test/test.dart';

void main() {
  test('getVersion returns a grpc version string', () async {
    final asyncVersion = await Utils.getVersion();
    expect(asyncVersion, startsWith('grpc.version='));
    expect(asyncVersion.split('=')[1], isNotEmpty);
  });

  test('getVersionSync matches async version', () async {
    final asyncVersion = await Utils.getVersion();
    final syncVersion = Utils.getVersionSync();
    expect(syncVersion, equals(asyncVersion));
  });

  test('randomId returns numeric id within range', () {
    for (var i = 0; i < 100; i++) {
      final id = int.parse(Utils.randomId(5));
      expect(id, inInclusiveRange(0, 4));
    }
  });

  test('getUuid returns unique values', () {
    expect(Utils.getUuid(), isNot(equals(Utils.getUuid())));
  });
}
