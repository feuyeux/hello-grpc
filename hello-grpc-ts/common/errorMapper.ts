/**
 * Error mapper for translating gRPC status codes to human-readable messages
 * and implementing retry logic with exponential backoff.
 */

import * as grpc from '@grpc/grpc-js';
import { initializeLogging } from './loggingConfig';

const logger = initializeLogging('errorMapper', 'logs', false);

/**
 * Configuration for retry logic
 */
export class RetryConfig {
  constructor(
    public maxRetries: number = 3,
    public initialDelay: number = 2000, // milliseconds
    public maxDelay: number = 30000, // milliseconds
    public multiplier: number = 2.0
  ) {}

  static default(): RetryConfig {
    return new RetryConfig();
  }
}

/**
 * Type for gRPC errors
 */
export interface GrpcError extends Error {
  code?: grpc.status;
  details?: string;
}

/**
 * Maps gRPC status codes to human-readable error messages
 * @param error - The error to map
 * @returns Human-readable error message
 */
export function mapGrpcError(error: Error | GrpcError | null | undefined): string {
  if (!error) {
    return 'Success';
  }

  const grpcError = error as GrpcError;
  if (grpcError.code !== undefined) {
    const description = getStatusDescription(grpcError.code);
    const message = grpcError.details || grpcError.message || '';

    if (message) {
      return `${description}: ${message}`;
    }
    return description;
  }

  return `Unknown error: ${error.message || error}`;
}

/**
 * Gets human-readable description for a gRPC status code
 * @param code - The status code
 * @returns Human-readable description
 */
function getStatusDescription(code: grpc.status): string {
  const descriptions: Record<grpc.status, string> = {
    [grpc.status.OK]: 'Success',
    [grpc.status.CANCELLED]: 'Operation cancelled',
    [grpc.status.UNKNOWN]: 'Unknown error',
    [grpc.status.INVALID_ARGUMENT]: 'Invalid request parameters',
    [grpc.status.DEADLINE_EXCEEDED]: 'Request timeout',
    [grpc.status.NOT_FOUND]: 'Resource not found',
    [grpc.status.ALREADY_EXISTS]: 'Resource already exists',
    [grpc.status.PERMISSION_DENIED]: 'Permission denied',
    [grpc.status.RESOURCE_EXHAUSTED]: 'Resource exhausted',
    [grpc.status.FAILED_PRECONDITION]: 'Precondition failed',
    [grpc.status.ABORTED]: 'Operation aborted',
    [grpc.status.OUT_OF_RANGE]: 'Out of range',
    [grpc.status.UNIMPLEMENTED]: 'Not implemented',
    [grpc.status.INTERNAL]: 'Internal server error',
    [grpc.status.UNAVAILABLE]: 'Service unavailable',
    [grpc.status.DATA_LOSS]: 'Data loss',
    [grpc.status.UNAUTHENTICATED]: 'Authentication required',
  };

  return descriptions[code] || 'Unknown error code';
}

/**
 * Determines if an error should be retried
 * @param error - The error to check
 * @returns True if the error is retryable, false otherwise
 */
export function isRetryableError(error: Error | GrpcError | null | undefined): boolean {
  if (!error) {
    return false;
  }

  const grpcError = error as GrpcError;
  if (grpcError.code === undefined) {
    return false;
  }

  const retryableCodes = [
    grpc.status.UNAVAILABLE,
    grpc.status.DEADLINE_EXCEEDED,
    grpc.status.RESOURCE_EXHAUSTED,
    grpc.status.INTERNAL,
  ];

  return retryableCodes.includes(grpcError.code);
}

/**
 * Handles RPC errors with logging and context
 * @param error - The error that occurred
 * @param operation - The operation name
 * @param context - Additional context information
 */
export function handleRpcError(
  error: Error | GrpcError | null | undefined,
  operation: string,
  context: Record<string, any> = {}
): void {
  if (!error) {
    return;
  }

  const errorMsg = mapGrpcError(error);
  const logContext = {
    ...context,
    operation,
    error: errorMsg,
  };

  if (isRetryableError(error)) {
    logger.warn(`Retryable error occurred: ${JSON.stringify(logContext)}`);
  } else {
    logger.error(`Non-retryable error occurred: ${JSON.stringify(logContext)}`);
  }
}

/**
 * Sleeps for the specified duration
 * @param ms - Milliseconds to sleep
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Executes a function with exponential backoff retry logic
 * @param operation - The operation name for logging
 * @param func - The function to execute (can return a Promise)
 * @param config - The retry configuration
 * @returns The result of the function
 * @throws Error if all retries are exhausted
 */
export async function retryWithBackoff<T>(
  operation: string,
  func: () => T | Promise<T>,
  config: RetryConfig | null = null
): Promise<T> {
  if (!config) {
    config = RetryConfig.default();
  }

  let lastError: Error | null = null;
  let delay = config.initialDelay;

  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    if (attempt > 0) {
      logger.info(
        `Retry attempt ${attempt}/${config.maxRetries} for ${operation} after ${delay}ms`
      );
      await sleep(delay);
    }

    try {
      const result = await Promise.resolve(func());
      if (attempt > 0) {
        logger.info(`Operation ${operation} succeeded after ${attempt + 1} attempts`);
      }
      return result;
    } catch (error) {
      lastError = error as Error;

      if (!isRetryableError(lastError)) {
        logger.warn(`Non-retryable error for ${operation}: ${mapGrpcError(lastError)}`);
        throw lastError;
      }

      if (attempt < config.maxRetries) {
        // Calculate next delay with exponential backoff
        delay = Math.min(delay * config.multiplier, config.maxDelay);
      }
    }
  }

  logger.error(
    `Operation ${operation} failed after ${config.maxRetries + 1} attempts: ${mapGrpcError(lastError)}`
  );
  const error = new Error(`Max retries exceeded for ${operation}`);
  (error as any).cause = lastError;
  throw error;
}
