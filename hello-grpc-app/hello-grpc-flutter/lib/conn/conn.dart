import 'package:flutter/foundation.dart';

class Conn {
  static String host = 'localhost';
  static int port = 9996;
  
  static void updateConnection(String newHost, int newPort) {
    host = newHost;
    port = newPort;
  }
  
  static Future<String> getLocalIP() async {
    if (kIsWeb) {
      // 在Web平台上，只能使用localhost
      return 'localhost';
    }
    
    // 在非Web平台上也简单使用localhost，避免复杂的网络接口查询
    return 'localhost';
  }
  
  static Future<void> initializeWithLocalIP() async {
    host = await getLocalIP();
  }
}
