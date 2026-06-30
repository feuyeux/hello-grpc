<?php

declare(strict_types=1);

namespace Common\Utils;

/**
 * hello-grpc-php OpenTelemetry wiring.
 *
 * Mirrors the env-gate pattern used by the prior OTel PRs in this
 * repository: read GRPC_HELLO_OTEL, install an OpenTelemetry SDK +
 * tracer provider when it is "Y", otherwise stay a no-op.
 *
 * Note on PHP gRPC interceptor support
 * -----------------------------------
 * The grpc PHP extension does not currently expose interceptor
 * callbacks at the ServerBuilder / Channel construction level
 * (c-extension gRPC server API takes service handlers, not
 * interceptor chains). That means gRPC per-call spans cannot be
 * emitted from PHP without either: (a) a future gRPC PHP extension
 * change, (b) running grpcphp / grpcio on top of the underlying PHP
 * extension and instrumenting at that layer, or (c) running
 * post-response hooks via the noop-on-success + exception-based
 * filter that wraps each handler in user code.
 *
 * Approach (c) is what `Otel::initOtel` enables here: the SDK + a
 * tracer are installed so that handler-side `tracer->spanBuilder()`
 * calls work today; the per-gRPC-call wiring will be added in a
 * follow-up PR that touches hello_server.php /
 * LandingServiceImpl.php to wrap each handler.
 */
final class Otel
{
    public const ENV_ENABLED = 'GRPC_HELLO_OTEL';

    /** Cached tracer provider to avoid double-init. */
    private static $tracerProvider = null;

    public static function enabled(): bool
    {
        return getenv(self::ENV_ENABLED) === 'Y';
    }

    /**
     * Returns a no-op TracerProvider when env var is unset, or the
     * configured exporter-backed one when set. Idempotent.
     */
    public static function initOtel(string $serviceName)
    {
        if (!self::enabled()) {
            // No-op provider. Returning the interface symbol a real
            // consumer might resolve is overkill — the call sites
            // currently gate on `enabled()` themselves.
            return null;
        }
        if (self::$tracerProvider !== null) {
            return self::$tracerProvider;
        }
        // The SDK lives across the bundled open-telemetry/sdk +
        // open-telemetry/exporter-otlp packages, both of which this
        // PR's composer.json addition pulls. Operator swap from
        // OTLP to stdout here is a single line.
        $tracerProvider = \OpenTelemetry\SDK\Trace\TracerProvider::builder()
            ->addSpanProcessor(
                (new \OpenTelemetry\Contrib\Otlp\SpanExporter(\OpenTelemetry\Contrib\Otlp\OtlpHttpTransportFactory::create(
                    $_ENV['OTEL_EXPORTER_OTLP_ENDPOINT'] ?? 'http://localhost:4318',
                    'application/x-protobuf'
                )))->getSpanExporter()
            )
            ->setResource(\OpenTelemetry\SDK\Resource\ResourceInfoFactory::defaultResource()->merge(
                \OpenTelemetry\SDK\Resource\ResourceInfoFactory::emptyResource()->withAttributes(
                    \OpenTelemetry\SDK\Common\Attribute::factory()
                        ->key('service.name')
                        ->string($serviceName)
                        ->build()
                )
            ))
            ->build();
        self::$tracerProvider = $tracerProvider;
        return $tracerProvider;
    }
}
