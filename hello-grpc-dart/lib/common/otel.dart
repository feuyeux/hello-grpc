// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart' as grpc;
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;

/// hello-grpc-dart OpenTelemetry wiring.
///
/// Mirrors the env-gate pattern in the prior OTel PRs across the
/// other languages. opt-in via `GRPC_HELLO_OTEL=Y`.

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
  if (!otelEnabled() || _initialized) {
    return;
  }
  _initialized = true;

  final provider = sdk.TracerProviderBase(
    processors: [sdk.SimpleSpanProcessor(sdk.ConsoleExporter())],
    resource: sdk.Resource([
      api.Attribute.fromString('service.name', serviceName),
      api.Attribute.fromString('service.version', '1.0.0'),
    ]),
  );
  api.registerGlobalTracerProvider(provider);

  // Print to stdout so the user can see wiring took effect.
  print('[otel] hello-grpc-dart tracing enabled for $serviceName');
}

/// Returns the global [api.Tracer], or `null` if OTel is disabled.
api.Tracer? get _tracer {
  if (!otelEnabled()) return null;
  return api.globalTracerProvider.getTracer('hello-grpc-dart');
}

api.Span? _startSpan(String name, api.SpanKind kind) {
  final tracer = _tracer;
  if (tracer == null) return null;
  return tracer.startSpan(
    name,
    kind: kind,
    attributes: [
      api.Attribute.fromString('rpc.system', 'grpc'),
      api.Attribute.fromString('rpc.method', name),
    ],
  );
}

/// Returns the client interceptor to attach to outgoing channels.
grpc.ClientInterceptor get clientInterceptor => const OtelClientInterceptor();

/// Returns the server interceptor to attach to grpc.Server.create(...).
grpc.ServerInterceptor get serverInterceptor => const OtelServerInterceptor();

// --- Client interceptor -----------------------------------------------------

/// gRPC client interceptor that creates an outbound [api.SpanKind.client] span
/// for each unary or streaming RPC and ends it when the response completes.
class OtelClientInterceptor implements grpc.ClientInterceptor {
  const OtelClientInterceptor();

  @override
  grpc.ResponseFuture<R> interceptUnary<Q, R>(
    grpc.ClientMethod<Q, R> method,
    Q request,
    grpc.CallOptions options,
    grpc.ClientUnaryInvoker<Q, R> invoker,
  ) {
    final span = _startSpan(method.path, api.SpanKind.client);
    if (span == null) return invoker(method, request, options);

    final response = invoker(method, request, options);
    response.then((_) {
      span.end();
    }, onError: (Object error) {
      span
        ..setStatus(api.StatusCode.error, error.toString())
        ..end();
    });
    return response;
  }

  @override
  grpc.ResponseStream<R> interceptStreaming<Q, R>(
    grpc.ClientMethod<Q, R> method,
    Stream<Q> requests,
    grpc.CallOptions options,
    grpc.ClientStreamingInvoker<Q, R> invoker,
  ) {
    final span = _startSpan(method.path, api.SpanKind.client);
    if (span == null) return invoker(method, requests, options);

    final response = invoker(method, requests, options);

    // ResponseStream hides the underlying stream; grpc-dart does not expose a
    // public way to wrap the response stream itself. We therefore end the span
    // when the single-response future resolves (which is derived from the same
    // underlying stream). For true full-stream tracing, the server side is the
    // more reliable span boundary because it can observe stream completion.
    response.single.then((_) {
      span.end();
    }, onError: (Object error) {
      span
        ..setStatus(api.StatusCode.error, error.toString())
        ..end();
    });

    return response;
  }
}

// --- Server interceptor -----------------------------------------------------

/// gRPC server interceptor that creates an inbound [api.SpanKind.server] span
/// for each RPC.
class OtelServerInterceptor implements grpc.ServerInterceptor {
  const OtelServerInterceptor();

  @override
  Stream<R> intercept<Q, R>(
    grpc.ServiceCall call,
    grpc.ServiceMethod<Q, R> method,
    Stream<Q> requests,
    grpc.ServerStreamingInvoker<Q, R> invoker,
  ) {
    final span = _startSpan(method.name, api.SpanKind.server);
    if (span == null) return invoker(call, method, requests);

    final response = api.contextWithSpan(api.Context.current, span).execute(
      () => invoker(call, method, requests),
    );
    return _SpanFinishingTransformer<R>(span).bind(response);
  }
}

class _SpanFinishingTransformer<T> extends StreamTransformerBase<T, T> {
  final api.Span span;
  _SpanFinishingTransformer(this.span);

  @override
  Stream<T> bind(Stream<T> stream) {
    return Stream<T>.eventTransformed(
      stream,
      (sink) => _SpanFinishingSink(sink, span),
    );
  }
}

class _SpanFinishingSink<T> implements EventSink<T> {
  final EventSink<T> _sink;
  final api.Span _span;
  bool _ended = false;

  _SpanFinishingSink(this._sink, this._span);

  void _end({Object? error}) {
    if (_ended) return;
    _ended = true;
    if (error != null) {
      _span.setStatus(api.StatusCode.error, error.toString());
    }
    _span.end();
  }

  @override
  void add(T event) => _sink.add(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _end(error: error);
    _sink.addError(error, stackTrace);
  }

  @override
  void close() {
    _end();
    _sink.close();
  }
}
