<?php

declare(strict_types=1);

namespace Common\Utils;

use Exception;
use OpenTelemetry\API\Common\Attribute\Attributes;
use OpenTelemetry\API\Trace\TracerInterface;
use OpenTelemetry\Contrib\Otlp\OtlpHttpTransportFactory;
use OpenTelemetry\Contrib\Otlp\SpanExporter;
use OpenTelemetry\SDK\Resource\ResourceInfo;
use OpenTelemetry\SDK\Resource\ResourceInfoFactory;
use OpenTelemetry\SDK\Trace\SpanProcessor\SimpleSpanProcessor;
use OpenTelemetry\SDK\Trace\TracerProvider;
use Throwable;

/**
 * hello-grpc-php OpenTelemetry wiring.
 *
 * Mirrors the env-gate pattern used by the prior OTel PRs in this
 * repository: read GRPC_HELLO_OTEL, install an OpenTelemetry SDK +
 * tracer provider when it is "Y", otherwise stay a no-op.
 *
 * PHP gRPC extension note
 * -----------------------
 * The grpc PHP extension does not expose interceptor callbacks at the
 * ServerBuilder / Channel construction level. Therefore per-gRPC-call
 * spans are emitted by wrapping each service handler in user code
 * with `Otel::wrapper($name, $callback, $attrs)`. This is the same
 * approach documented in our initial OTel PR (#493).
 */
final class Otel
{
    public const ENV_ENABLED = 'GRPC_HELLO_OTEL';

    /** Cached tracer provider to avoid double-init. */
    private static ?TracerProvider $tracerProvider = null;

    /** Cached tracer. */
    private static ?TracerInterface $tracer = null;

    /** OTel-gated in-process RPC call counter. */
    private static int $rpcCallsTotal = 0;

    public static function enabled(): bool
    {
        return getenv(self::ENV_ENABLED) === 'Y';
    }

    /**
     * Initialize the PHP OpenTelemetry tracer provider.
     *
     * The PHP gRPC extension has no server interceptor hook, so handler
     * methods create spans through wrapper(). This method exists so the
     * server/client startup path can eagerly validate and cache the SDK.
     */
    public static function initOtel(string $serviceName): ?TracerProvider
    {
        if (!self::enabled()) {
            return null;
        }

        self::tracer();
        return self::$tracerProvider;
    }

    /**
     * Increment the OTel-gated rpc_calls_total counter.
     */
    public static function recordRpcCall(string $method): void
    {
        if (!self::enabled()) {
            return;
        }

        self::$rpcCallsTotal++;
        error_log(sprintf(
            '[otel-metric] rpc_calls_total=%d rpc.system=grpc rpc.service=LandingService rpc.method=%s',
            self::$rpcCallsTotal,
            $method
        ));
    }

    /**
     * Build (or return cached) Sdk TracerProvider and tracer.
     */
    public static function tracer(): TracerInterface
    {
        if (self::$tracer !== null) {
            return self::$tracer;
        }

        if (!self::enabled()) {
            // Should not be called when disabled; wrapper() gates before
            // calling tracer(). Returning the SDK no-op tracer is safe.
            return \OpenTelemetry\API\Trace\NoopTracer::getInstance();
        }

        $endpoint = $_ENV['OTEL_EXPORTER_OTLP_ENDPOINT']
            ?? $_SERVER['OTEL_EXPORTER_OTLP_ENDPOINT']
            ?? 'http://localhost:4318';

        $transport = OtlpHttpTransportFactory::create(
            rtrim($endpoint, '/') . '/v1/traces',
            'application/x-protobuf'
        );
        $exporter = new SpanExporter($transport);

        $resource = ResourceInfoFactory::defaultResource()->merge(
            ResourceInfo::create(Attributes::create([
                'service.name' => 'hello-grpc-php',
            ]))
        );

        self::$tracerProvider = TracerProvider::builder()
            ->addSpanProcessor(new SimpleSpanProcessor($exporter))
            ->setResource($resource)
            ->build();

        self::$tracer = self::$tracerProvider->getTracer('hello-grpc-php');
        return self::$tracer;
    }

    /**
     * Execute `$callback` inside an OTel span. When GRPC_HELLO_OTEL is
     * unset this degrades to a plain callback invocation with near-zero
     * overhead.
     *
     * @param string   $name     span name, typically the gRPC method
     * @param callable $callback body to wrap
     * @param array    $attrs    key/value pairs added as span attributes
     *
     * @return mixed the value returned by $callback
     * @throws Throwable any exception thrown by $callback is re-thrown
     *                   after being recorded on the span
     */
    public static function wrapper(string $name, callable $callback, array $attrs = [])
    {
        if (!self::enabled()) {
            return $callback();
        }

        self::recordRpcCall($name);
        $tracer = self::tracer();
        $builder = $tracer->spanBuilder($name);
        foreach ($attrs as $key => $value) {
            $builder = $builder->setAttribute((string) $key, $value);
        }
        $span = $builder->startSpan();

        try {
            $result = $callback();
            return $result;
        } catch (Throwable $e) {
            $span->recordException($e);
            throw $e;
        } finally {
            $span->end();
        }
    }
}
