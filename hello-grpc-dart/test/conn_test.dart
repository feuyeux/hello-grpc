import 'package:test/test.dart';
import 'package:hello_grpc_dart/conn/conn.dart'; // Path to the Conn class
import 'dart:io' show Platform, Directory, File;
import 'package:path/path.dart' as p;

void main() {
  group('Conn Tests', () {
    // Helper function to temporarily set environment variables
    Map<String, String?> originalEnv; // Allow null values for keys that might not exist

    setUp(() {
      // Store original environment variables to restore them later
      originalEnv = Map.from(Platform.environment);
    });

    tearDown(() {
      // Restore original environment variables
      // Clear variables that might have been set during the test
      var currentKeys = Set.from(Platform.environment.keys);
      var originalKeys = Set.from(originalEnv.keys);

      for (var key in currentKeys) {
        if (!originalKeys.contains(key)) {
          // This key was added by the test, remove it
          Platform.environment.remove(key);
        } else {
          // This key was originally present, restore its value
          // If originalEnv[key] was null, it means it was not set originally, so remove.
          // However, Platform.environment does not allow null values.
          // The logic here assumes originalEnv will store actual values or absence.
          // If a key was in originalEnv, it means it had a value.
          Platform.environment[key] = originalEnv[key]!;
        }
      }
      // Add back any keys that were in originalEnv but are no longer in Platform.environment
      // (though typically tests add/modify, not remove system vars)
      for (var key in originalKeys) {
        if (!Platform.environment.containsKey(key) && originalEnv[key] != null) {
           Platform.environment[key] = originalEnv[key]!;
        }
      }
    });

    test('isSecure should be true if GRPC_HELLO_SECURE is Y', () {
      Platform.environment['GRPC_HELLO_SECURE'] = 'Y';
      expect(Conn.isSecure, isTrue);
      Platform.environment.remove('GRPC_HELLO_SECURE'); // Clean up
    });

    test('isSecure should be false if GRPC_HELLO_SECURE is not Y', () {
      Platform.environment['GRPC_HELLO_SECURE'] = 'N';
      expect(Conn.isSecure, isFalse);
      Platform.environment.remove('GRPC_HELLO_SECURE');
    });

    test('isSecure should be false if GRPC_HELLO_SECURE is not set', () {
      Platform.environment.remove('GRPC_HELLO_SECURE'); // Ensure it's not set
      expect(Conn.isSecure, isFalse);
    });

    test('getServerPort should return default port if GRPC_SERVER_PORT is not set', () {
      Platform.environment.remove('GRPC_SERVER_PORT');
      expect(Conn.getServerPort(), Conn.port); // Conn.port is the default
    });

    test('getServerPort should return custom port if GRPC_SERVER_PORT is set and valid', () {
      Platform.environment['GRPC_SERVER_PORT'] = '12345';
      expect(Conn.getServerPort(), 12345);
      Platform.environment.remove('GRPC_SERVER_PORT');
    });

    test('getServerPort should return default port if GRPC_SERVER_PORT is invalid', () {
      Platform.environment['GRPC_SERVER_PORT'] = 'invalid';
      expect(Conn.getServerPort(), Conn.port);
      Platform.environment.remove('GRPC_SERVER_PORT');
    });

    test('certBasePath should use CERT_BASE_PATH env var if set', () {
      final testPath = '/tmp/test_certs';
      Platform.environment['CERT_BASE_PATH'] = testPath;
      expect(Conn.certBasePath, testPath);
      Platform.environment.remove('CERT_BASE_PATH');
    });

    group('validateCertificates', () {
      final String tempCertsDir = p.join(Directory.current.path, 'test_temp_certs');
      String? originalCertBasePathEnv; // Can be null if not set

      setUp(() async {
        originalCertBasePathEnv = Platform.environment['CERT_BASE_PATH']; // Store before overwriting
        await Directory(tempCertsDir).create(recursive: true);
        Platform.environment['CERT_BASE_PATH'] = tempCertsDir; // Override base path for tests
      });

      tearDown(() async {
        if (await Directory(tempCertsDir).exists()) {
          await Directory(tempCertsDir).delete(recursive: true);
        }
        // Restore original CERT_BASE_PATH or remove if it wasn't there
        if (originalCertBasePathEnv != null) {
          Platform.environment['CERT_BASE_PATH'] = originalCertBasePathEnv!;
        } else {
          Platform.environment.remove('CERT_BASE_PATH');
        }
      });

      test('should return true if not secure', () {
        Platform.environment.remove('GRPC_HELLO_SECURE'); // Ensure not secure
        expect(Conn.validateCertificates(), isTrue);
      });

      test('should return true if secure and cert/key files exist', () async {
        Platform.environment['GRPC_HELLO_SECURE'] = 'Y';
        await File(p.join(tempCertsDir, 'cert.pem')).create();
        await File(p.join(tempCertsDir, 'private.pkcs8.key')).create();
        expect(Conn.validateCertificates(), isTrue);
      });

      test('should return false if secure and cert file is missing', () async {
        Platform.environment['GRPC_HELLO_SECURE'] = 'Y';
        await File(p.join(tempCertsDir, 'private.pkcs8.key')).create();
        if (await File(p.join(tempCertsDir, 'cert.pem')).exists()) {
          await File(p.join(tempCertsDir, 'cert.pem')).delete();
        }
        expect(Conn.validateCertificates(), isFalse);
      });

      test('should return false if secure and key file is missing', () async {
        Platform.environment['GRPC_HELLO_SECURE'] = 'Y';
        await File(p.join(tempCertsDir, 'cert.pem')).create();
        if (await File(p.join(tempCertsDir, 'private.pkcs8.key')).exists()) {
          await File(p.join(tempCertsDir, 'private.pkcs8.key')).delete();
        }
        expect(Conn.validateCertificates(), isFalse);
      });
    });

    test('hasBackend should be true if GRPC_HELLO_BACKEND is set and not empty', () {
      Platform.environment['GRPC_HELLO_BACKEND'] = 'localhost';
      expect(Conn.hasBackend, isTrue);
      Platform.environment.remove('GRPC_HELLO_BACKEND');
    });

    test('hasBackend should be false if GRPC_HELLO_BACKEND is empty', () {
      Platform.environment['GRPC_HELLO_BACKEND'] = '';
      expect(Conn.hasBackend, isFalse);
      Platform.environment.remove('GRPC_HELLO_BACKEND');
    });

    test('hasBackend should be false if GRPC_HELLO_BACKEND is not set', () {
      Platform.environment.remove('GRPC_HELLO_BACKEND');
      expect(Conn.hasBackend, isFalse);
    });

  });
}
