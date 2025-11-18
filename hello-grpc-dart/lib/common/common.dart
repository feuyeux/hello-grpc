/// Common utilities for the gRPC Dart implementation.
///
/// This module provides helper functions for:
/// - Generating random IDs
/// - Creating UUIDs
/// - Getting timestamps
/// - Retrieving version information
library;

import 'dart:io' show File, Directory;
import 'dart:math' show Random;

import 'package:fixnum/fixnum.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

/// Utility class providing common helper functions
class Utils {
  static const Uuid _uuid = Uuid();

  /// Get current timestamp in milliseconds since epoch
  static Int64 timestamp() {
    return Int64(DateTime.now().millisecondsSinceEpoch);
  }

  /// Generate a random ID between 0 and max-1
  ///
  /// [max] The upper bound (exclusive) for the random number
  /// Returns a string representation of the random number
  static String randomId(int max) {
    final id = Random().nextInt(max);
    return id.toString();
  }

  /// Generate a UUID v4
  ///
  /// Returns a randomly generated UUID string
  static String getUuid() {
    return _uuid.v4();
  }

  /// Get the gRPC version from pubspec.yaml or fallback to a default value
  ///
  /// Returns a string in the format 'grpc.version=X.Y.Z'
  static String getVersion() {
    try {
      // Try to get version from the pubspec.lock file (most accurate)
      final lockPath = path.join(Directory.current.path, 'pubspec.lock');
      final lockFile = File(lockPath);

      if (lockFile.existsSync()) {
        final content = lockFile.readAsStringSync();
        final lock = loadYaml(content);

        if (lock['packages'] != null &&
            lock['packages']['grpc'] != null &&
            lock['packages']['grpc']['version'] != null) {
          final version = lock['packages']['grpc']['version'].toString();
          return 'grpc.version=$version';
        }
      }

      // Fallback: Try to get from pubspec.yaml
      final pubspecPath = path.join(Directory.current.path, 'pubspec.yaml');
      final pubspecFile = File(pubspecPath);

      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        final pubspec = loadYaml(content);

        if (pubspec['dependencies'] != null &&
            pubspec['dependencies']['grpc'] != null) {
          var version = pubspec['dependencies']['grpc'].toString();
          // Clean up the version if it has ^ or >= prefixes
          version = version.replaceAll(RegExp(r'[^\d.]'), '');
          return 'grpc.version=$version';
        }
      }
    } on Exception catch (e) {
      // Silently fail and use fallback
      // ignore: avoid_print
      print('Error getting gRPC version: $e');
    }

    // Default fallback if version cannot be determined
    return 'grpc.version=unknown';
  }
}
