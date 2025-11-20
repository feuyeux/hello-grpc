/**
 * Unified error mapper for converting JavaScript errors to gRPC status codes.
 * 
 * This module provides consistent error handling across the gRPC service by mapping
 * common application errors to appropriate gRPC status codes according to the
 * unified error handling strategy.
 * 
 * Error Mapping Rules:
 * - Input Validation Failed → INVALID_ARGUMENT
 * - Request Timeout → DEADLINE_EXCEEDED
 * - Backend Unreachable → UNAVAILABLE
 * - Authentication Failed → UNAUTHENTICATED
 * - Permission Denied → PERMISSION_DENIED
 * - Resource Not Found → NOT_FOUND
 * - Resource Already Exists → ALREADY_EXISTS
 * - Internal Server Error → INTERNAL
 */

const grpc = require('@grpc/grpc-js');

/**
 * Maps a JavaScript error to an appropriate gRPC status code.
 * 
 * @param {Error} error - The error to map
 * @param {string} requestId - The request ID for logging context
 * @returns {number} The appropriate gRPC status code
 */
function mapToStatusCode(error, requestId = '') {
  if (!error) {
    return grpc.status.OK;
  }

  // Already a gRPC error - preserve it
  if (error.code !== undefined && typeof error.code === 'number') {
    return error.code;
  }

  const errorMessage = (error.message || '').toLowerCase();
  const errorName = (error.name || '').toLowerCase();

  // Timeout errors
  if (errorName.includes('timeout') || 
      errorMessage.includes('timeout') ||
      errorMessage.includes('timed out') ||
      errorMessage.includes('deadline')) {
    return grpc.status.DEADLINE_EXCEEDED;
  }

  // Connection errors
  if (errorName.includes('connection') ||
      errorMessage.includes('econnrefused') ||
      errorMessage.includes('econnreset') ||
      errorMessage.includes('enotfound') ||
      errorMessage.includes('ehostunreach') ||
      errorMessage.includes('enetunreach') ||
      errorMessage.includes('unavailable') ||
      errorMessage.includes('unreachable')) {
    return grpc.status.UNAVAILABLE;
  }

  // Validation errors
  if (errorName.includes('validation') ||
      errorName.includes('typeerror') ||
      errorName.includes('rangeerror') ||
      errorMessage.includes('invalid') ||
      errorMessage.includes('validation') ||
      errorMessage.includes('bad request')) {
    return grpc.status.INVALID_ARGUMENT;
  }

  // Authentication errors
  if (errorName.includes('authentication') ||
      errorName.includes('unauthorized') ||
      errorMessage.includes('authentication') ||
      errorMessage.includes('unauthorized') ||
      errorMessage.includes('unauthenticated')) {
    return grpc.status.UNAUTHENTICATED;
  }

  // Permission errors
  if (errorName.includes('permission') ||
      errorName.includes('forbidden') ||
      errorMessage.includes('permission') ||
      errorMessage.includes('forbidden') ||
      errorMessage.includes('access denied') ||
      errorMessage.includes('eacces')) {
    return grpc.status.PERMISSION_DENIED;
  }

  // Not found errors
  if (errorName.includes('notfound') ||
      errorMessage.includes('not found') ||
      errorMessage.includes('no such') ||
      errorMessage.includes('enoent')) {
    return grpc.status.NOT_FOUND;
  }

  // Already exists errors
  if (errorName.includes('exists') ||
      errorMessage.includes('already exists') ||
      errorMessage.includes('duplicate') ||
      errorMessage.includes('eexist')) {
    return grpc.status.ALREADY_EXISTS;
  }

  // Cancelled errors
  if (errorName.includes('cancel') ||
      errorMessage.includes('cancel') ||
      errorMessage.includes('abort')) {
    return grpc.status.CANCELLED;
  }

  // Default to INTERNAL for unknown errors
  return grpc.status.INTERNAL;
}

/**
 * Gets a formatted error message from an error.
 * 
 * @param {Error} error - The error to format
 * @returns {string} A formatted error message
 */
function getErrorMessage(error) {
  if (!error) {
    return '';
  }

  if (error.details) {
    return error.details;
  }

  if (error.message) {
    return error.message;
  }

  return error.toString();
}

/**
 * Converts a JavaScript error to a gRPC error object.
 * 
 * @param {Error} error - The error that occurred
 * @param {string} requestId - The request ID for logging context
 * @returns {Object} A gRPC error object with code and details
 */
function toGrpcError(error, requestId = '') {
  const statusCode = mapToStatusCode(error, requestId);
  let message = getErrorMessage(error);

  // Add request ID to error details if available
  if (requestId) {
    message = `[request_id=${requestId}] ${message}`;
  }

  return {
    code: statusCode,
    details: message,
    metadata: new grpc.Metadata()
  };
}

/**
 * Gets a human-readable error code for logging purposes.
 * 
 * @param {Error} error - The error to get code for
 * @returns {string} The error code name
 */
function getErrorCode(error) {
  if (!error) {
    return '';
  }

  const statusCode = mapToStatusCode(error);
  
  // Find the status name from the grpc.status object
  for (const [key, value] of Object.entries(grpc.status)) {
    if (value === statusCode) {
      return key;
    }
  }

  return 'UNKNOWN';
}

/**
 * Wraps a callback with unified error handling.
 * 
 * @param {Function} callback - The gRPC callback function
 * @param {string} requestId - The request ID for logging context
 * @returns {Function} A wrapped callback with error handling
 */
function wrapCallback(callback, requestId = '') {
  return (error, response) => {
    if (error) {
      const grpcError = toGrpcError(error, requestId);
      callback(grpcError, null);
    } else {
      callback(null, response);
    }
  };
}

/**
 * Handles an error in a streaming context.
 * 
 * @param {Object} call - The gRPC call object
 * @param {Error} error - The error that occurred
 * @param {string} requestId - The request ID for logging context
 */
function handleStreamError(call, error, requestId = '') {
  const grpcError = toGrpcError(error, requestId);
  call.emit('error', {
    code: grpcError.code,
    details: grpcError.details,
    metadata: grpcError.metadata
  });
}

/**
 * Logs an error with unified format including request ID.
 * 
 * @param {Error} error - The error that occurred
 * @param {string} requestId - The request ID for logging context
 * @param {string} method - The method name where the error occurred
 */
function logError(error, requestId, method) {
  if (!error) {
    return;
  }

  const errorCode = getErrorCode(error);
  const errorMsg = getErrorMessage(error);

  // Get logger from connection module
  const conn = require('./connection');
  const logger = conn.logger;

  logger.error(`Request failed - request_id: ${requestId}, method: ${method}, error_code: ${errorCode}, message: ${errorMsg}`);
}

module.exports = {
  mapToStatusCode,
  getErrorMessage,
  toGrpcError,
  getErrorCode,
  wrapCallback,
  handleStreamError,
  logError
};
