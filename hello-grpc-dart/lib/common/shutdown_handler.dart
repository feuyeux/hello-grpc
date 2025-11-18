import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';

final _logger = Logger('ShutdownHandler');

const _defaultShutdownTimeout = Duration(seconds: 30);

/// Manages graceful shutdown of the application
class ShutdownHandler {
  ShutdownHandler({this.timeout = _defaultShutdownTimeout}) {
    _registerSignalHandlers();
  }

  final Duration timeout;
  final List<Future<void> Function()> _cleanupFunctions = [];
  bool _shutdownInitiated = false;
  final Completer<void> _shutdownCompleter = Completer<void>();

  /// Registers signal handlers for SIGINT and SIGTERM
  void _registerSignalHandlers() {
    // Handle SIGINT (Ctrl+C)
    ProcessSignal.sigint.watch().listen((signal) {
      _logger.info('Received SIGINT signal');
      initiateShutdown();
    });

    // Handle SIGTERM
    ProcessSignal.sigterm.watch().listen((signal) {
      _logger.info('Received SIGTERM signal');
      initiateShutdown();
    });
  }

  /// Registers a cleanup function to be called during shutdown
  void registerCleanup(Future<void> Function() cleanupFn) {
    _cleanupFunctions.add(cleanupFn);
  }

  /// Registers a synchronous cleanup function
  void registerCleanupSync(void Function() cleanupFn) {
    _cleanupFunctions.add(() async => cleanupFn());
  }

  /// Initiates the shutdown process
  void initiateShutdown() {
    if (_shutdownInitiated) {
      return;
    }
    _shutdownInitiated = true;
    _logger.info('Shutdown initiated');

    if (!_shutdownCompleter.isCompleted) {
      _shutdownCompleter.complete();
    }
  }

  /// Checks if shutdown has been initiated
  bool get isShutdownInitiated => _shutdownInitiated;

  /// Waits for a shutdown signal
  Future<void> wait() async {
    await _shutdownCompleter.future;
  }

  /// Performs graceful shutdown with timeout
  /// Returns true if shutdown completed successfully, false if timeout occurred
  Future<bool> shutdown() async {
    _logger.info('Starting graceful shutdown...');

    try {
      // Execute cleanup functions in reverse order (LIFO) with timeout
      await Future.wait(
        _cleanupFunctions.reversed.map((cleanupFn) async {
          try {
            await cleanupFn();
          } on Exception catch (e, stackTrace) {
            _logger.severe('Error during cleanup: $e', e, stackTrace);
          }
        }),
      ).timeout(
        timeout,
        onTimeout: () {
          _logger.warning('Shutdown timeout exceeded, forcing shutdown');
          throw TimeoutException('Shutdown timeout');
        },
      );

      _logger.info('Graceful shutdown completed successfully');
      return true;
    } on TimeoutException {
      return false;
    } on Exception catch (e) {
      _logger.severe('Error during shutdown: $e');
      return false;
    }
  }

  /// Waits for a shutdown signal and then performs shutdown
  /// Returns true if shutdown completed successfully, false if timeout occurred
  Future<bool> waitAndShutdown() async {
    await wait();
    return shutdown();
  }
}
