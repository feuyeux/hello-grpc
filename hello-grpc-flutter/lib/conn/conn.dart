import 'dart:io';

class Conn {
  static String host = 'localhost';
  static int port = 9996;
  
  static void updateConnection(String newHost, int newPort) {
    host = newHost;
    port = newPort;
  }
  
  static Future<String> getLocalIP() async {
    try {
      // 获取所有网络接口
      final interfaces = await NetworkInterface.list();
      
      // 优先查找WiFi或以太网接口的IPv4地址
      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('en') || 
            interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi')) {
          for (final addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      
      // 如果没找到，返回第一个非回环的IPv4地址
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('Error getting local IP: $e');
    }
    
    return 'localhost';
  }
  
  static Future<void> initializeWithLocalIP() async {
    host = await getLocalIP();
  }
}
