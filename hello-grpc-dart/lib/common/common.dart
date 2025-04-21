import 'package:fixnum/src/int64.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' show Random;

class Utils {
  static Uuid uuid = Uuid();

  static Int64 timestamp() {
    return Int64(DateTime.now().millisecondsSinceEpoch);
  }

  static String randomId(int max) {
    var id = Random().nextInt(max);
    return id.toString();
  }

  static String getUuid() {
    return uuid.v4();
  }
}
