import 'package:hello_grpc_dart/common/common.dart';
import 'package:test/test.dart';

int Add(int x, int y) {
  return x + y;
}

void main() {
  test("test to check add method", () {
    var expected = 30;
    var actual = Add(10, 20);
    expect(actual, expected);
  });

  group("Utils", () {
    test("test uuid", () {
      var uuid = Utils.getUuid();
      expect(uuid.length, equals(36));
    });
    test("test timestamp", () {
      var timestamp = Utils.timestamp();
      expect(timestamp, greaterThan(0));
    });
    test("test randomId", () {
      var string = "  foo ";
      expect(string.trim(), equals("foo"));
    });
  });
}
