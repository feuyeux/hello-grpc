<?php
/**
 * Unified log formatter for gRPC services.
 * 
 * Provides consistent logging format across all RPC methods with standard fields:
 * service, request_id, method, peer, secure, duration_ms, status
 */

namespace Common\Utils;

use Monolog\Logger;

class LogFormatter
{
    private const SERVICE_NAME = 'php';
    private static $isSecure = null;

    /**
     * Check if connection is secure
     */
    private static function isSecure(): bool
    {
        if (self::$isSecure === null) {
            self::$isSecure = getenv('GRPC_HELLO_SECURE') === 'Y';
        }
        return self::$isSecure;
    }

    /**
     * Extract request ID from metadata
     * Supports multiple request-id key variants for consistency with other languages
     */
    public static function extractRequestId(array $metadata): string
    {
        // Try multiple request ID header variants in order of preference
        $requestIdKeys = ['x-request-id', 'request-id', 'x-trace-id'];
        
        foreach ($requestIdKeys as $key) {
            if (isset($metadata[$key])) {
                $value = $metadata[$key];
                // Handle both array and string values
                if (is_array($value)) {
                    return !empty($value[0]) ? $value[0] : 'unknown';
                } else if (is_string($value) && !empty($value)) {
                    return $value;
                }
            }
        }
        
        // Generate a new request ID if none found
        return 'php-' . uniqid('', true);
    }

    /**
     * Extract peer address from context
     */
    public static function extractPeer($context): string
    {
        // Try to get peer from context if available
        if (method_exists($context, 'getPeer')) {
            $peer = $context->getPeer();
            return $peer ?: 'unknown';
        }
        return 'unknown';
    }

    /**
     * Log request start
     */
    public static function logRequestStart(
        Logger $logger,
        string $method,
        string $requestId,
        string $peer
    ): float {
        $secure = self::isSecure();
        $startTime = microtime(true);

        $logger->info(sprintf(
            'service=%s request_id=%s method=%s peer=%s secure=%s status=STARTED',
            self::SERVICE_NAME,
            $requestId,
            $method,
            $peer,
            $secure ? 'true' : 'false'
        ));

        return $startTime;
    }

    /**
     * Log request end
     */
    public static function logRequestEnd(
        Logger $logger,
        string $method,
        string $requestId,
        string $peer,
        float $startTime,
        string $status = 'OK'
    ): void {
        $secure = self::isSecure();
        $durationMs = (int)((microtime(true) - $startTime) * 1000);

        $logger->info(sprintf(
            'service=%s request_id=%s method=%s peer=%s secure=%s duration_ms=%d status=%s',
            self::SERVICE_NAME,
            $requestId,
            $method,
            $peer,
            $secure ? 'true' : 'false',
            $durationMs,
            $status
        ));
    }

    /**
     * Log request error
     */
    public static function logRequestError(
        Logger $logger,
        string $method,
        string $requestId,
        string $peer,
        float $startTime,
        string $statusCode,
        string $errorCode,
        string $message,
        ?\Throwable $exception = null
    ): void {
        $secure = self::isSecure();
        $durationMs = (int)((microtime(true) - $startTime) * 1000);

        $logMessage = sprintf(
            'service=%s request_id=%s method=%s peer=%s secure=%s duration_ms=%d status=%s error_code=%s message=%s',
            self::SERVICE_NAME,
            $requestId,
            $method,
            $peer,
            $secure ? 'true' : 'false',
            $durationMs,
            $statusCode,
            $errorCode,
            $message
        );

        if ($exception !== null) {
            $logger->error($logMessage, ['exception' => $exception]);
        } else {
            $logger->error($logMessage);
        }
    }

    /**
     * Extract tracing headers from metadata
     * Supports multiple request-id key variants
     */
    public static function extractTracingHeaders(array $metadata): array
    {
        $tracingHeaders = [
            'x-request-id',
            'request-id',      // Added for consistency
            'x-trace-id',      // Added for consistency
            'x-b3-traceid',
            'x-b3-spanid',
            'x-b3-parentspanid',
            'x-b3-sampled',
            'x-b3-flags',
            'x-ot-span-context'
        ];

        $result = [];
        foreach ($tracingHeaders as $header) {
            if (isset($metadata[$header])) {
                $value = $metadata[$header];
                // Handle both array and string values
                if (is_array($value)) {
                    $result[$header] = !empty($value[0]) ? $value[0] : '';
                } else {
                    $result[$header] = $value;
                }
            }
        }

        return $result;
    }
}
