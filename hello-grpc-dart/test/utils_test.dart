import 'package:test/test.dart';
import 'package:hello_grpc_dart/common/utils.dart';
import 'dart:io'; // For File operations if we mock files later
import 'package:path/path.dart' as p; // For path joining if we mock files later

// This is the fallback version hardcoded for tests, as the original is private.
const String _TEST_FALLBACK_GRPC_VERSION = '4.0.1';

void main() {
  group('Utils Tests', () {
    group('getVersion and getVersionSync', () {
      // Directory for temporary test files
      final testDir = p.join(Directory.current.path, 'test', 'temp_test_files');
      final projectRootPubspecLockPath = 'pubspec.lock';
      final projectRootPubspecYamlPath = 'pubspec.yaml';
      final backupLockPath = p.join(testDir, 'pubspec.lock.bak');
      final backupYamlPath = p.join(testDir, 'pubspec.yaml.bak');


      setUp(() async {
        // Create a temporary directory for test files
        await Directory(testDir).create(recursive: true);

        // Backup original pubspec.lock and pubspec.yaml if they exist
        if (await File(projectRootPubspecLockPath).exists()) {
          await File(projectRootPubspecLockPath).rename(backupLockPath);
        }
        if (await File(projectRootPubspecYamlPath).exists()) {
          await File(projectRootPubspecYamlPath).rename(backupYamlPath);
        }
      });

      tearDown(() async {
        // Delete any test-created pubspec files
        if (await File(projectRootPubspecLockPath).exists()) {
          await File(projectRootPubspecLockPath).delete();
        }
        if (await File(projectRootPubspecYamlPath).exists()) {
          await File(projectRootPubspecYamlPath).delete();
        }

        // Restore original pubspec.lock and pubspec.yaml if they were backed up
        if (await File(backupLockPath).exists()) {
          await File(backupLockPath).rename(projectRootPubspecLockPath);
        }
        if (await File(backupYamlPath).exists()) {
          await File(backupYamlPath).rename(projectRootPubspecYamlPath);
        }

        // Clean up the temporary directory
        if (await Directory(testDir).exists()) {
          await Directory(testDir).delete(recursive: true);
        }
      });

      test('should return fallback version if no pubspec files exist', () async {
        // Ensure no pubspec files are present for this test
        // (Handled by setUp and tearDown, but good to be explicit)
        expect(await Utils.getVersion(), 'grpc.version=$_TEST_FALLBACK_GRPC_VERSION');
        expect(Utils.getVersionSync(), 'grpc.version=$_TEST_FALLBACK_GRPC_VERSION');
      });

      test('should read version from pubspec.lock if it exists', () async {
        await File(projectRootPubspecLockPath).writeAsString('''
packages:
  grpc:
    version: "3.2.1"
''');
        // Ensure pubspec.yaml does not exist or does not contain a grpc version to ensure .lock is used
        if (await File(projectRootPubspecYamlPath).exists()) {
          await File(projectRootPubspecYamlPath).delete();
        }

        expect(await Utils.getVersion(), 'grpc.version=3.2.1');
        expect(Utils.getVersionSync(), 'grpc.version=3.2.1');
      });

      test('should read version from pubspec.yaml if pubspec.lock is not present or lacks version', () async {
        // Ensure pubspec.lock doesn't exist or doesn't have the version
        if (await File(projectRootPubspecLockPath).exists()) {
           await File(projectRootPubspecLockPath).delete();
        }
        // Create a pubspec.lock without grpc version (or an empty one)
        await File(projectRootPubspecLockPath).writeAsString('''
packages:
  some_other_package:
    version: "1.0.0"
''');

        await File(projectRootPubspecYamlPath).writeAsString('''
name: hello_grpc_dart
dependencies:
  grpc: ^3.0.0 
''');
        // Utils.dart cleans version from ^3.0.0 to 3.0.0
        expect(await Utils.getVersion(), 'grpc.version=3.0.0');
        expect(Utils.getVersionSync(), 'grpc.version=3.0.0');
      });
      
      test('should prioritize pubspec.lock over pubspec.yaml', () async {
        await File(projectRootPubspecLockPath).writeAsString('''
packages:
  grpc:
    version: "3.2.1" # Version from .lock
''');
        await File(projectRootPubspecYamlPath).writeAsString('''
name: hello_grpc_dart
dependencies:
  grpc: ^3.0.0 # Version from .yaml
''');
        expect(await Utils.getVersion(), 'grpc.version=3.2.1');
        expect(Utils.getVersionSync(), 'grpc.version=3.2.1');
      });


    });

    group('Other Utils', () {
      test('timestamp returns current time in milliseconds (approx)', () {
        final now = DateTime.now().millisecondsSinceEpoch;
        final ts = Utils.timestamp().toInt();
        expect(ts, greaterThanOrEqualTo(now - 100)); 
        expect(ts, lessThanOrEqualTo(now + 1000)); // Increased upper bound for safety on slower systems
      });

      test('randomId returns a string representing an int within max range', () {
        final max = 100;
        final idString = Utils.randomId(max);
        expect(idString, isA<String>());
        final idInt = int.tryParse(idString);
        expect(idInt, isNotNull, reason: 'Random ID "$idString" should be an integer string');
        if (idInt != null) { 
            expect(idInt, allOf(greaterThanOrEqualTo(0), lessThan(max)));
        }
      });

      test('getUuid returns a valid V4 UUID', () {
        final uuid = Utils.getUuid();
        expect(uuid, matches(RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')),
               reason: "Generated UUID $uuid is not a valid V4 UUID");
      });
    });
  });
}
