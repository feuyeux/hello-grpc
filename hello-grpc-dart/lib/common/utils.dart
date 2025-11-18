import 'dart:io';
import 'dart:math' show Random;

import 'package:fixnum/fixnum.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

class Utils {
  // Fallback version if unable to get dynamically
  static const String _fallbackGrpcVersion = '4.0.1';

  static const Uuid uuid = Uuid();
  static final Logger _logger = Logger('Utils');

  static Int64 timestamp() {
    return Int64(DateTime.now().millisecondsSinceEpoch);
  }

  static String randomId(int max) {
    final id = Random().nextInt(max);
    return id.toString();
  }

  static String getUuid() {
    return uuid.v4();
  }

  /// Get gRPC version, try to get from pubspec.lock file or fallback to default version
  static Future<String> getVersion() async {
    final version = await _getGrpcVersionAsync();
    _logger.fine('[Utils] Async version retrieved: $version');
    return 'grpc.version=$version';
  }

  /// Synchronous version for backward compatibility
  static String getVersionSync() {
    final version = _getGrpcVersionSync();
    _logger.fine('[Utils] Sync version retrieved: $version');
    return 'grpc.version=$version';
  }

  /// Try to get gRPC version from pubspec.lock file (async version)
  static Future<String> _getGrpcVersionAsync() async {
    try {
      // Try to get from pubspec.lock
      final lockPath = path.join(Directory.current.path, 'pubspec.lock');
      final lockFile = File(lockPath);

      if (lockFile.existsSync()) {
        final content = await lockFile.readAsString();
        final lock = loadYaml(content);

        if (lock != null &&
            lock['packages'] != null &&
            lock['packages']['grpc'] != null &&
            lock['packages']['grpc']['version'] != null) {
          final version = lock['packages']['grpc']['version'].toString();
          _logger.fine('[Utils] Version from pubspec.lock: $version');
          return version;
        }
        _logger.fine('[Utils] grpc version not found in pubspec.lock');
      } else {
        _logger.fine('[Utils] pubspec.lock file does not exist: $lockPath');
      }

      // If unable to get from pubspec.lock, check pubspec.yaml
      final pubspecPath = path.join(Directory.current.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);

      if (pubspecFile.existsSync()) {
        final content = await pubspecFile.readAsString();
        final pubspec = loadYaml(content);

        if (pubspec != null &&
            pubspec['dependencies'] != null &&
            pubspec['dependencies']['grpc'] != null) {
          var version = pubspec['dependencies']['grpc'].toString();
          // Clean version number (remove ^ >= etc prefixes)
          version = version.replaceAll(RegExp(r'[^\d.]'), '');
          _logger.fine('[Utils] Version from pubspec.yaml: $version');
          return version;
        }
        _logger.fine('[Utils] grpc version not found in pubspec.yaml');
      } else {
        _logger.fine('[Utils] pubspec.yaml file does not exist: $pubspecPath');
      }
    } on Exception catch (e) {
      _logger.warning('[Utils] Exception during async version retrieval: $e');
    }

    _logger.fine('[Utils] Using fallback version: $_fallbackGrpcVersion');
    return _fallbackGrpcVersion;
  }

  /// Synchronous version, read pubspec.lock file to get gRPC version
  static String _getGrpcVersionSync() {
    try {
      // Try to get from pubspec.lock
      final lockPath = path.join(Directory.current.path, 'pubspec.lock');
      final lockFile = File(lockPath);

      if (lockFile.existsSync()) {
        final content = lockFile.readAsStringSync();
        final lock = loadYaml(content);

        if (lock != null &&
            lock['packages'] != null &&
            lock['packages']['grpc'] != null &&
            lock['packages']['grpc']['version'] != null) {
          final version = lock['packages']['grpc']['version'].toString();
          _logger.fine('[Utils] Sync version from pubspec.lock: $version');
          return version;
        }
        _logger.fine('[Utils] grpc version not found in pubspec.lock (sync)');
      } else {
        _logger.fine(
          '[Utils] pubspec.lock file does not exist (sync): $lockPath',
        );
      }

      // If unable to get from pubspec.lock, check pubspec.yaml
      final pubspecPath = path.join(Directory.current.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);

      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final pubspec = loadYaml(content);

        if (pubspec != null &&
            pubspec['dependencies'] != null &&
            pubspec['dependencies']['grpc'] != null) {
          var version = pubspec['dependencies']['grpc'].toString();
          // Clean version number (remove ^ >= etc prefixes)
          version = version.replaceAll(RegExp(r'[^\d.]'), '');
          _logger.fine('[Utils] Sync version from pubspec.yaml: $version');
          return version;
        }
        _logger.fine('[Utils] grpc version not found in pubspec.yaml (sync)');
      } else {
        _logger.fine(
          '[Utils] pubspec.yaml file does not exist (sync): $pubspecPath',
        );
      }
    } on Exception catch (e) {
      _logger.warning('[Utils] Exception during sync version retrieval: $e');
    }

    _logger.fine(
      '[Utils] Using fallback version (sync): $_fallbackGrpcVersion',
    );
    return _fallbackGrpcVersion;
  }
}
