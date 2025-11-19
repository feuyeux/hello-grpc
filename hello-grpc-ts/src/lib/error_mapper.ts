/**
 * Unified error mapper for converting TypeScript errors to gRPC status codes.
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

import * as grpc from '@grpc/grpc-js';

/**
 * Maps a TypeScript error to an appropriate gRPC status code.
 * 
 * @param error - The error to map
 * @param requestId - The request ID for logging context
 * @returns The appropriate gRPC status code
 */
export function mapToStatusCode(error: any, requestId: string = ''): grpc.status {
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
 * @param error - The error to format
 * @returns A formatted error message
 */
export function getErrorMessage(error: any): string {
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
 * Converts a TypeScript error to a gRPC error object.
 * 
 * @param error - The error that occurred
 * @param requestId - The request ID for logging context
 * @returns A gRPC error object with code and details
 */
export function toGrpcError(error: any, requestId: string = ''): grpc.ServiceError {
  const statusCode = mapToStatusCode(error, requestId);
  let message = getErrorMessage(error);

  // Add request ID to error details if available
  if (requestId) {
    message = `[request_id=${requestId}] ${message}`;
  }

  const grpcError: grpc.ServiceError = {
    name: 'ServiceError',
    message: message,
    code: statusCode,
    details: message,
    metadata: new grpc.Metadata()
  };

  return grpcError;
}

/**
 * Gets a human-readable error code for logging purposes.
 * 
 * @param error - The error to get code for
 * @returns The error code name
 */
export function getErrorCode(error: any): string {
  if (!error) {
    return '';
  }

  const statusCode = mapToStatusCode(error);
  
  // Find the status name from the grpc.status enum
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
 * @param callback - The gRPC callback function
 * @param requestId - The request ID for logging context
 * @returns A wrapped callback with error handling
 */
export function wrapCallback<T>(
  callback: grpc.sendUnaryData<T>,
  requestId: string = ''
): grpc.sendUnaryData<T> {
  return ((error: grpc.ServiceError | null, response?: T) => {
    if (error) {
      const grpcError = toGrpcError(error, requestId);
      callback(grpcError, undefined);
    } else {
      callback(null, response);
    }
  }) as grpc.sendUnaryData<T>;
}

/**
 * Handles an error in a streaming context.
 * 
 * @param call - The gRPC call object
 * @param error - The error that occurred
 * @param requestId - The request ID for logging context
 */
export function handleStreamError(
  call: any,
  error: any,
  requestId: string = ''
): void {
  const grpcError = toGrpcError(error, requestId);
  call.emit('error', grpcError);
}

/**
 * Error handler decorator for async methods.
 * 
 * @param target - The target object
 * @param propertyKey - The method name
 * @param descriptor - The property descriptor
 */
export function HandleErrors(
  target: any,
  propertyKey: string,
  descriptor: PropertyDescriptor
): PropertyDescriptor {
  const originalMethod = descriptor.value;

  descriptor.value = async function (...args: any[]) {
    try {
      return await originalMethod.apply(this, args);
    } catch (error) {
      // Find the callback in the arguments
      const callback = args.find(arg => typeof arg === 'function');
      if (callback) {
        const grpcError = toGrpcError(error);
        callback(grpcError, null);
      } else {
        throw toGrpcError(error);
      }
    }
  };

  return descriptor;
}
