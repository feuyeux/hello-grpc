import 'package:fixnum/src/int64.dart';
import 'package:uuid/uuid.dart';
import 'dart:math' show Random;
import 'dart:io' show File, Directory;
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;

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
  
  /// Get the gRPC version from pubspec.yaml or fallback to a default value
  static String getVersion() {
    try {
      // Try to get version from the pubspec.yaml file
      var pubspecPath = path.join(Directory.current.path, 'pubspec.yaml');
      var file = File(pubspecPath);
      
      if (file.existsSync()) {
        var content = file.readAsStringSync();
        var pubspec = loadYaml(content);
        
        // Look for grpc dependency in pubspec.yaml
        if (pubspec['dependencies'] != null && 
            pubspec['dependencies']['grpc'] != null) {
          var version = pubspec['dependencies']['grpc'].toString();
          // Clean up the version if it has ^ or >= prefixes
          version = version.replaceAll(RegExp(r'[^\d.]'), '');
          return 'grpc.version=$version';
        }
      }
      
      // Fallback: Try to get from pubspec.lock which might have the resolved version
      var lockPath = path.join(Directory.current.path, 'pubspec.lock');
      var lockFile = File(lockPath);
      
      if (lockFile.existsSync()) {
        var content = lockFile.readAsStringSync();
        var lock = loadYaml(content);
        
        if (lock['packages'] != null && 
            lock['packages']['grpc'] != null && 
            lock['packages']['grpc']['version'] != null) {
          var version = lock['packages']['grpc']['version'].toString();
          return 'grpc.version=$version';
        }
      }
    } catch (e) {
      print('Error getting gRPC version: $e');
    }
    
    // Default fallback if version cannot be determined
    return 'grpc.version=unknown';
  }
}
