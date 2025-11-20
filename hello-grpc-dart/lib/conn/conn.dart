import 'dart:io' as io;
import 'package:path/path.dart' as path;

/// Connection configuration for the gRPC server
class Conn {
  /// Default server port
  static int port = 9996;

  /// Whether to use TLS for secure connections
  static bool get isSecure =>
      io.Platform.environment['GRPC_HELLO_SECURE']?.toUpperCase() == 'Y';

  /// Gets the base path for certificate files
  static String get certBasePath {
    // Check for environment variable override first
    final envPath = io.Platform.environment['CERT_BASE_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      return envPath;
    }

    // Use platform-specific default paths
    if (io.Platform.isWindows) {
      return r'd:\garden\var\hello_grpc\server_certs';
    } else if (io.Platform.isMacOS) {
      return '/var/hello_grpc/server_certs';
    } else {
      // Linux and others
      return '/var/hello_grpc/server_certs';
    }
  }

  /// Gets the client certificate base path (for root CA)
  static String get clientCertBasePath {
    // For client, we use client_certs path for mutual TLS
    final envPath = io.Platform.environment['CERT_BASE_PATH'];
    if (envPath != null && envPath.isNotEmpty) {
      return envPath;
    }

    // Use platform-specific default paths
    if (io.Platform.isWindows) {
      return r'd:\garden\var\hello_grpc\client_certs';
    } else if (io.Platform.isMacOS) {
      return '/var/hello_grpc/client_certs';
    } else {
      // Linux and others
      return '/var/hello_grpc/client_certs';
    }
  }

  /// Path to the server certificate
  static String get certPath => path.join(certBasePath, 'cert.pem');

  /// Path to the server private key
  static String get keyPath => path.join(certBasePath, 'private.pkcs8.key');

  /// Path to the certificate chain
  static String get chainPath => path.join(certBasePath, 'full_chain.pem');

  /// Path to the root certificate (for client to verify server)
  static String get rootCertPath =>
      path.join(clientCertBasePath, 'full_chain.pem');

  /// Backend host for proxy mode, null if not configured
  static String? get backendHost =>
      io.Platform.environment['GRPC_HELLO_BACKEND'];

  /// Whether backend connection is configured
  static bool get hasBackend => backendHost != null && backendHost!.isNotEmpty;

  /// Gets custom port from environment variable or uses the default
  static int getServerPort() {
    final portStr = io.Platform.environment['GRPC_SERVER_PORT'];
    if (portStr != null && portStr.isNotEmpty) {
      try {
        return int.parse(portStr);
      } on Exception {
        // If parsing fails, use default port
      }
    }
    return port;
  }

  /// Checks if all required certificate files exist
  static bool validateCertificates() {
    if (!isSecure) {
      return true;
    }

    final certFile = io.File(certPath);
    final keyFile = io.File(keyPath);

    return certFile.existsSync() && keyFile.existsSync();
  }
}
