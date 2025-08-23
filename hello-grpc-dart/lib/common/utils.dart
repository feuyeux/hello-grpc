import 'package:fixnum/src/int64.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' show Random;
import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

class Utils {
  // 定义备用版本，以防无法动态获取
  static const String _FALLBACK_GRPC_VERSION = '4.0.1';

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

  /// 获取 gRPC 版本，尝试从 pubspec.lock 文件获取或回退到默认版本
  static Future<String> getVersion() async {
    var version = await _getGrpcVersionAsync();
    print('[Utils] 异步获取版本: $version');
    return 'grpc.version=$version';
  }

  /// 同步版本，为了向后兼容
  static String getVersionSync() {
    var version = _getGrpcVersionSync();
    print('[Utils] 同步获取版本: $version');
    return 'grpc.version=$version';
  }

  /// 尝试从 pubspec.lock 文件获取 gRPC 版本 (异步版本)
  static Future<String> _getGrpcVersionAsync() async {
    try {
      // 尝试从 pubspec.lock 中获取
      var lockPath = path.join(Directory.current.path, 'pubspec.lock');
      var lockFile = File(lockPath);

      if (await lockFile.exists()) {
        var content = await lockFile.readAsString();
        var lock = loadYaml(content);

        if (lock != null &&
            lock['packages'] != null &&
            lock['packages']['grpc'] != null &&
            lock['packages']['grpc']['version'] != null) {
          var version = lock['packages']['grpc']['version'].toString();
          print('[Utils] 从 pubspec.lock 中获取到版本: $version');
          return version;
        }
        print('[Utils] pubspec.lock 中未找到 grpc 版本信息');
      } else {
        print('[Utils] pubspec.lock 文件不存在: $lockPath');
      }

      // 如果无法从 pubspec.lock 获取，检查 pubspec.yaml
      var pubspecPath = path.join(Directory.current.path, 'pubspec.yaml');
      var pubspecFile = File(pubspecPath);

      if (await pubspecFile.exists()) {
        var content = await pubspecFile.readAsString();
        var pubspec = loadYaml(content);

        if (pubspec != null &&
            pubspec['dependencies'] != null &&
            pubspec['dependencies']['grpc'] != null) {
          var version = pubspec['dependencies']['grpc'].toString();
          // 清理版本号（移除 ^ >= 等前缀）
          version = version.replaceAll(RegExp(r'[^\d.]'), '');
          print('[Utils] 从 pubspec.yaml 中获取到版本: $version');
          return version;
        }
        print('[Utils] pubspec.yaml 中未找到 grpc 版本信息');
      } else {
        print('[Utils] pubspec.yaml 文件不存在: $pubspecPath');
      }
    } catch (e) {
      print('[Utils] 异步获取版本时发生异常: $e');
    }

    print('[Utils] 使用备用版本: $_FALLBACK_GRPC_VERSION');
    return _FALLBACK_GRPC_VERSION;
  }

  /// 同步版本，读取 pubspec.lock 文件获取 gRPC 版本
  static String _getGrpcVersionSync() {
    try {
      // 尝试从 pubspec.lock 中获取
      var lockPath = path.join(Directory.current.path, 'pubspec.lock');
      var lockFile = File(lockPath);

      if (lockFile.existsSync()) {
        var content = lockFile.readAsStringSync();
        var lock = loadYaml(content);

        if (lock != null &&
            lock['packages'] != null &&
            lock['packages']['grpc'] != null &&
            lock['packages']['grpc']['version'] != null) {
          var version = lock['packages']['grpc']['version'].toString();
          print('[Utils] 从 pubspec.lock 中同步获取到版本: $version');
          return version;
        }
        print('[Utils] pubspec.lock 中未找到 grpc 版本信息（同步）');
      } else {
        print('[Utils] pubspec.lock 文件不存在（同步）: $lockPath');
      }

      // 如果无法从 pubspec.lock 获取，检查 pubspec.yaml
      var pubspecPath = path.join(Directory.current.path, 'pubspec.yaml');
      var pubspecFile = File(pubspecPath);

      if (pubspecFile.existsSync()) {
        var content = pubspecFile.readAsStringSync();
        var pubspec = loadYaml(content);

        if (pubspec != null &&
            pubspec['dependencies'] != null &&
            pubspec['dependencies']['grpc'] != null) {
          var version = pubspec['dependencies']['grpc'].toString();
          // 清理版本号（移除 ^ >= 等前缀）
          version = version.replaceAll(RegExp(r'[^\d.]'), '');
          print('[Utils] 从 pubspec.yaml 中同步获取到版本: $version');
          return version;
        }
        print('[Utils] pubspec.yaml 中未找到 grpc 版本信息（同步）');
      } else {
        print('[Utils] pubspec.yaml 文件不存在（同步）: $pubspecPath');
      }
    } catch (e) {
      print('[Utils] 同步获取版本时发生异常: $e');
    }

    print('[Utils] 使用备用版本（同步）: $_FALLBACK_GRPC_VERSION');
    return _FALLBACK_GRPC_VERSION;
  }
}
