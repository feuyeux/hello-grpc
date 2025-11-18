/// Logging configuration for standardized logging setup.
///
/// Provides utilities to initialize logging with standard format:
/// `[TIMESTAMP] [LEVEL] [COMPONENT] MESSAGE [CONTEXT]`
///
/// Uses Dart's logging package with dual output (console and file).
library;

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

const String defaultLogDir = 'logs';
final DateFormat timestampFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
final DateFormat fileTimestampFormat = DateFormat('yyyyMMdd_HHmmss');

/// Logging configuration helper
class LoggingConfig {
  /// Initialize logging for a component with dual output (console and file)
  ///
  /// [component] - The component name (e.g., "client", "server")
  /// [logDir] - The directory for log files (default: "logs")
  /// [enableFile] - Whether to enable file logging (default: true)
  ///
  /// Returns the configured logger instance
  static Logger initializeLogging(
    String component, {
    String logDir = defaultLogDir,
    bool enableFile = true,
  }) {
    // Create log directory
    if (enableFile) {
      final dir = Directory(logDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    }

    // Get log level
    final level = getLogLevel();

    // Configure logging
    Logger.root.level = level;

    // Create log file if enabled
    File? logFile;
    if (enableFile) {
      final timestamp = fileTimestampFormat.format(DateTime.now());
      final logFileName = '${component}_$timestamp.log';
      final logFilePath = '$logDir/$logFileName';
      logFile = File(logFilePath);
    }

    // Set up log handler
    Logger.root.onRecord.listen((record) {
      final timestamp = timestampFormat.format(record.time);
      final level = record.level.name;
      final message = record.message;

      // Build context from error and stack trace
      var context = '';
      if (record.error != null || record.stackTrace != null) {
        final contextParts = <String>[];
        if (record.error != null) {
          contextParts.add('error=${record.error}');
        }
        if (contextParts.isNotEmpty) {
          context = ' [${contextParts.join(', ')}]';
        }
      }

      // Build log line
      final logLine =
          '[$timestamp] [$level] [${record.loggerName}] $message$context';

      // Output to console
      // ignore: avoid_print
      print(logLine);

      // Output to file if enabled
      if (logFile != null) {
        logFile.writeAsStringSync('$logLine\n', mode: FileMode.append);
      }

      // Add stack trace if present
      if (record.stackTrace != null) {
        final stackTrace = record.stackTrace.toString();
        // ignore: avoid_print
        print(stackTrace);
        if (logFile != null) {
          logFile.writeAsStringSync('$stackTrace\n', mode: FileMode.append);
        }
      }
    });

    // Create logger
    final logger = Logger(component)
      ..info('Logging initialized for component: $component');
    if (enableFile) {
      logger.info('Log directory: $logDir');
    }

    return logger;
  }

  /// Get log level from environment variable or default to INFO
  static Level getLogLevel() {
    final levelStr = Platform.environment['LOG_LEVEL']?.toUpperCase() ?? 'INFO';

    switch (levelStr) {
      case 'ALL':
        return Level.ALL;
      case 'FINEST':
      case 'TRACE':
        return Level.FINEST;
      case 'FINER':
      case 'DEBUG':
        return Level.FINER;
      case 'FINE':
        return Level.FINE;
      case 'CONFIG':
        return Level.CONFIG;
      case 'INFO':
        return Level.INFO;
      case 'WARNING':
      case 'WARN':
        return Level.WARNING;
      case 'SEVERE':
      case 'ERROR':
        return Level.SEVERE;
      case 'SHOUT':
      case 'FATAL':
        return Level.SHOUT;
      case 'OFF':
        return Level.OFF;
      default:
        return Level.INFO;
    }
  }
}

/// Convenience function to initialize logging
Logger initializeLogging(
  String component, {
  String logDir = defaultLogDir,
  bool enableFile = true,
}) {
  return LoggingConfig.initializeLogging(
    component,
    logDir: logDir,
    enableFile: enableFile,
  );
}
