<?php

namespace Common\Utils;

use Grpc\Status;
use Exception;

/**
 * Configuration for retry logic
 */
class RetryConfig
{
    public int $maxRetries;
    public float $initialDelay; // seconds
    public float $maxDelay; // seconds
    public float $multiplier;

    public function __construct(
        int $maxRetries = 3,
        float $initialDelay = 2.0,
        float $maxDelay = 30.0,
        float $multiplier = 2.0
    ) {
        $this->maxRetries = $maxRetries;
        $this->initialDelay = $initialDelay;
        $this->maxDelay = $maxDelay;
        $this->multiplier = $multiplier;
    }

    public static function default(): self
    {
        return new self();
    }
}

/**
 * Error mapper for translating gRPC status codes to human-readable messages
 * and implementing retry logic with exponential backoff.
 */
class ErrorMapper
{
    /**
     * Maps gRPC status codes to human-readable error messages
     *
     * @param Exception|null $error The error to map
     * @return string Human-readable error message
     */
    public static function mapGrpcError(?Exception $error): string
    {
        if ($error === null) {
            return 'Success';
        }

        $code = $error->getCode();
        $message = $error->getMessage();
        $description = self::getStatusDescription($code);

        if (!empty($message)) {
            return "$description: $message";
        }
        return $description;
    }

    /**
     * Gets human-readable description for a gRPC status code
     *
     * @param int $code The status code
     * @return string Human-readable description
     */
    private static function getStatusDescription(int $code): string
    {
        $descriptions = [
            Status::OK => 'Success',
            Status::CANCELLED => 'Operation cancelled',
            Status::UNKNOWN => 'Unknown error',
            Status::INVALID_ARGUMENT => 'Invalid request parameters',
            Status::DEADLINE_EXCEEDED => 'Request timeout',
            Status::NOT_FOUND => 'Resource not found',
            Status::ALREADY_EXISTS => 'Resource already exists',
            Status::PERMISSION_DENIED => 'Permission denied',
            Status::RESOURCE_EXHAUSTED => 'Resource exhausted',
            Status::FAILED_PRECONDITION => 'Precondition failed',
            Status::ABORTED => 'Operation aborted',
            Status::OUT_OF_RANGE => 'Out of range',
            Status::UNIMPLEMENTED => 'Not implemented',
            Status::INTERNAL => 'Internal server error',
            Status::UNAVAILABLE => 'Service unavailable',
            Status::DATA_LOSS => 'Data loss',
            Status::UNAUTHENTICATED => 'Authentication required',
        ];

        return $descriptions[$code] ?? 'Unknown error code';
    }

    /**
     * Determines if an error should be retried
     *
     * @param Exception|null $error The error to check
     * @return bool True if the error is retryable, false otherwise
     */
    public static function isRetryableError(?Exception $error): bool
    {
        if ($error === null) {
            return false;
        }

        $code = $error->getCode();
        $retryableCodes = [
            Status::UNAVAILABLE,
            Status::DEADLINE_EXCEEDED,
            Status::RESOURCE_EXHAUSTED,
            Status::INTERNAL,
        ];

        return in_array($code, $retryableCodes, true);
    }

    /**
     * Handles RPC errors with logging and context
     *
     * @param Exception|null $error The error that occurred
     * @param string $operation The operation name
     * @param array $context Additional context information
     */
    public static function handleRpcError(?Exception $error, string $operation, array $context = []): void
    {
        if ($error === null) {
            return;
        }

        $errorMsg = self::mapGrpcError($error);
        $logContext = array_merge($context, [
            'operation' => $operation,
            'error' => $errorMsg,
        ]);

        $logger = LoggingConfig::getLogger();
        $contextStr = json_encode($logContext);

        if (self::isRetryableError($error)) {
            $logger->warning("Retryable error occurred: $contextStr");
        } else {
            $logger->error("Non-retryable error occurred: $contextStr");
        }
    }

    /**
     * Executes a function with exponential backoff retry logic
     *
     * @param string $operation The operation name for logging
     * @param callable $func The function to execute
     * @param RetryConfig|null $config The retry configuration
     * @return mixed The result of the function
     * @throws Exception If all retries are exhausted
     */
    public static function retryWithBackoff(string $operation, callable $func, ?RetryConfig $config = null)
    {
        if ($config === null) {
            $config = RetryConfig::default();
        }

        $lastError = null;
        $delay = $config->initialDelay;
        $logger = LoggingConfig::getLogger();

        for ($attempt = 0; $attempt <= $config->maxRetries; $attempt++) {
            if ($attempt > 0) {
                $delayMs = (int)($delay * 1000);
                $logger->info(
                    "Retry attempt $attempt/{$config->maxRetries} for $operation after {$delayMs}ms"
                );
                usleep($delayMs * 1000); // usleep takes microseconds
            }

            try {
                $result = $func();
                if ($attempt > 0) {
                    $attempts = $attempt + 1;
                    $logger->info("Operation $operation succeeded after $attempts attempts");
                }
                return $result;
            } catch (Exception $e) {
                $lastError = $e;

                if (!self::isRetryableError($e)) {
                    $errorMsg = self::mapGrpcError($e);
                    $logger->warning("Non-retryable error for $operation: $errorMsg");
                    throw $e;
                }

                if ($attempt < $config->maxRetries) {
                    // Calculate next delay with exponential backoff
                    $delay = min($delay * $config->multiplier, $config->maxDelay);
                }
            }
        }

        $attempts = $config->maxRetries + 1;
        $errorMsg = self::mapGrpcError($lastError);
        $logger->error("Operation $operation failed after $attempts attempts: $errorMsg");
        
        throw new Exception("Max retries exceeded for $operation", 0, $lastError);
    }
}
