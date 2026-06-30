// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:opentelemetry_dart/opentelemetry_dart.dart';

/// hello-grpc-dart OpenTelemetry wiring.
///
/// Mirrors the env-gate pattern in the prior OTel PRs across the
/// other languages. opt-in via `GRPC_HELLO_OTEL=Y`.
///
/// Caveat: grpc-dart does not yet ship an OpenTelemetry client/
/// server interceptor at the time of writing, so this module
/// exposes a minimal tracer that future interceptor code can be
/// built around. The env var also installs a tracer provider so
/// that any in-process tracer usage (service handlers, custom
/// async spans) works against a configured global tracer. The
/// interceptor half follows in a follow-up PR.

bool _enabled = false;
bool _initialized = false;

bool otelEnabled() {
  if (_enabled) return true;
  final v = Platform.environment['GRPC_HELLO_OTEL'];
  _enabled = v == 'Y';
  return _enabled;
}

/// One-time TracerProvider + tracer install for the calling
/// process. Idempotent. No-op when otel is not enabled.
Future<void> initOtel(String serviceName) async {
  if (!otelEnabled() || _initialized) return;
  _initialized = true;

  // Process-level resource. The default global propagator + exporter
  // wiring is provided by package:opentelemetry_dart; stdout is the
  // teaching/demo posture across the other languages.
  final resource = OTelResource(
    serviceName: serviceName,
    serviceVersion: '0.1.0',
  );
  final exporter = OTelConsoleExporter();
  final provider = OTelTracerProvider(resource: resource, exporter: exporter);
  OTelTrace.register(provider, setAsGlobal: true);

  // Print to stdout so the user can see wiring took effect.
  // ignore: avoid_print
  print('[otel] hello-grpc-dart tracing enabled for $serviceName');
}
