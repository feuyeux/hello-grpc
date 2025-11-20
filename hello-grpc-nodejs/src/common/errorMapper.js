/**
 * Error mapper for translating gRPC status codes to human-readable messages
 * and implementing retry logic with exponential backoff.
 */

const grpc = require('@grpc/grpc-js');
const logger = require('./loggingConfig');

/**
 * Configuration for retry logic
 */
class RetryConfig {
  constructor(maxRetries = 3, initialDelay = 2000, maxDelay = 30000, multiplier = 2.0) {
    this.maxRetries = maxRetries;
    this.initialDelay = initialDelay; // milliseconds
    this.maxDelay = maxDelay; // milliseconds
    this.multiplier = multiplier;
  }

  static default() {
    return new RetryConfig();
  }
}

/**
 * Maps gRPC status codes to human-readable error messages
 * @param {Error} error - The error to map
 * @returns {string} Human-readable error message
 */
function mapGrpcError(error) {
  if (!error) {
    return 'Success';
  }

  if (error.code !== undefined) {
    const description = getStatusDescription(error.code);
    const message = error.details || error.message || '';

    if (message) {
      return `${description}: ${message}`;
    }
    return description;
  }

  return `Unknown error: ${error.message || error}`;
}

/**
 * Gets human-readable description for a gRPC status code
 * @param {number} code - The status code
 * @returns {string} Human-readable description
 */
function getStatusDescription(code) {
  const descriptions = {
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
 * @param {Error} error - The error to check
 * @returns {boolean} True if the error is retryable, false otherwise
 */
function isRetryableError(error) {
  if (!error || error.code === undefined) {
    return false;
  }

  const retryableCodes = [
    grpc.status.UNAVAILABLE,
    grpc.status.DEADLINE_EXCEEDED,
    grpc.status.RESOURCE_EXHAUSTED,
    grpc.status.INTERNAL,
  ];

  return retryableCodes.includes(error.code);
}

/**
 * Handles RPC errors with logging and context
 * @param {Error} error - The error that occurred
 * @param {string} operation - The operation name
 * @param {Object} context - Additional context information
 */
function handleRpcError(error, operation, context = {}) {
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
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise<void>}
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Executes a function with exponential backoff retry logic
 * @param {string} operation - The operation name for logging
 * @param {Function} func - The function to execute (can return a Promise)
 * @param {RetryConfig} config - The retry configuration
 * @returns {Promise<*>} The result of the function
 * @throws {Error} If all retries are exhausted
 */
async function retryWithBackoff(operation, func, config = null) {
  if (!config) {
    config = RetryConfig.default();
  }

  let lastError = null;
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
      lastError = error;

      if (!isRetryableError(error)) {
        logger.warn(`Non-retryable error for ${operation}: ${mapGrpcError(error)}`);
        throw error;
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
  error.cause = lastError;
  throw error;
}

module.exports = {
  RetryConfig,
  mapGrpcError,
  isRetryableError,
  handleRpcError,
  retryWithBackoff,
};
