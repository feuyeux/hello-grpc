import 'package:grpc/grpc.dart';

// NOTE on gzip compression: the Dart `grpc` package (pinned per AGENTS.md)
// does not expose a message-compression / codec configuration hook on
// [ChannelOptions] as of this writing, unlike Go/Python/Java/C++/C#/Node/
// TS/PHP/Rust in this repo which all enable gzip at the channel level.
// There is nothing to wire up here until the package adds that support;
// tracked as a known parity gap rather than implemented with a nonexistent
// API.

/// A6 client-retry parameters for hello.LandingService, mirroring the
/// grpc.service_config retryPolicy used by the other language clients:
/// https://github.com/grpc/proposal/blob/master/A6-client-retries.md
///
/// The Dart `grpc` package has no built-in service-config/retryPolicy
/// support, so this is applied at the application level around unary
/// calls instead of via channel configuration.
class Retry {
  static const int maxAttempts = 4;
  static const Duration initialBackoff = Duration(milliseconds: 100);
  static const Duration maxBackoff = Duration(seconds: 1);
  static const double backoffMultiplier = 2;

  /// Returns true when [code] matches the retryableStatusCodes used by the
  /// shared A6 retry policy (`UNAVAILABLE` only).
  static bool _isRetryable(int code) => code == StatusCode.unavailable;

  /// Runs [call] up to [maxAttempts] times, retrying only on `UNAVAILABLE`
  /// with exponential backoff (initial 0.1s, multiplier 2.0, capped at 1s)
  /// - the same policy encoded in the other languages' `retryPolicy`
  /// service config for `hello.LandingService`.
  static Future<T> run<T>(String method, Future<T> Function() call) async {
    var backoff = initialBackoff;
    GrpcError? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await call();
      } on GrpcError catch (e) {
        lastError = e;
        if (attempt == maxAttempts || !_isRetryable(e.code)) {
          rethrow;
        }
        await Future.delayed(backoff);
        final nextMicros = backoff.inMicroseconds * backoffMultiplier;
        backoff = Duration(microseconds: nextMicros.round());
        if (backoff > maxBackoff) {
          backoff = maxBackoff;
        }
      }
    }
    throw lastError ?? const GrpcError.unavailable('retry loop exhausted');
  }
}
