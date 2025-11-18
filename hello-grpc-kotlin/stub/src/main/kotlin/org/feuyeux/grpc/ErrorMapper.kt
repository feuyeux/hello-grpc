package org.feuyeux.grpc

import io.grpc.Status
import io.grpc.StatusException
import io.grpc.StatusRuntimeException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.io.IOException
import java.util.concurrent.TimeoutException

/**
 * Unified error mapper for converting exceptions to gRPC status codes.
 * 
 * This object provides consistent error handling across the gRPC service by mapping
 * common application exceptions to appropriate gRPC status codes according to the
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
object ErrorMapper {

    /**
     * Maps a throwable to an appropriate gRPC Status.
     * 
     * @param throwable The exception to map
     * @param requestId The request ID for logging context
     * @return A gRPC Status with appropriate code and description
     */
    fun mapToStatus(throwable: Throwable?, requestId: String): Status {
        if (throwable == null) {
            return Status.INTERNAL.withDescription("Unknown error")
        }

        // Already a gRPC status exception - preserve it
        when (throwable) {
            is StatusRuntimeException -> return throwable.status
            is StatusException -> return throwable.status
        }

        // Map common exceptions to gRPC status codes
        val message = throwable.message ?: throwable.javaClass.simpleName
        
        // Timeout errors
        if (throwable is TimeoutException || throwable is SocketTimeoutException) {
            return Status.DEADLINE_EXCEEDED
                .withDescription("Request timeout: $message")
                .withCause(throwable)
        }

        // Connection errors
        if (throwable is ConnectException || 
            throwable is UnknownHostException || 
            throwable is IOException) {
            return Status.UNAVAILABLE
                .withDescription("Backend service unavailable: $message")
                .withCause(throwable)
        }

        // Validation errors
        if (throwable is IllegalArgumentException || 
            throwable is NullPointerException) {
            return Status.INVALID_ARGUMENT
                .withDescription("Invalid input: $message")
                .withCause(throwable)
        }

        // Authentication errors
        if (throwable.javaClass.simpleName.contains("Authentication") ||
            throwable.javaClass.simpleName.contains("Unauthorized")) {
            return Status.UNAUTHENTICATED
                .withDescription("Authentication failed: $message")
                .withCause(throwable)
        }

        // Permission errors
        if (throwable is SecurityException ||
            throwable.javaClass.simpleName.contains("Permission") ||
            throwable.javaClass.simpleName.contains("Forbidden")) {
            return Status.PERMISSION_DENIED
                .withDescription("Permission denied: $message")
                .withCause(throwable)
        }

        // Not found errors
        if (throwable.javaClass.simpleName.contains("NotFound") ||
            throwable.javaClass.simpleName.contains("NoSuch")) {
            return Status.NOT_FOUND
                .withDescription("Resource not found: $message")
                .withCause(throwable)
        }

        // Already exists errors
        if (throwable.javaClass.simpleName.contains("AlreadyExists") ||
            throwable.javaClass.simpleName.contains("Duplicate")) {
            return Status.ALREADY_EXISTS
                .withDescription("Resource already exists: $message")
                .withCause(throwable)
        }

        // Default to INTERNAL for unknown errors
        return Status.INTERNAL
            .withDescription("Internal server error")
            .withCause(throwable)
    }

    /**
     * Wraps an exception handling block with unified error mapping.
     * 
     * @param throwable The exception that occurred
     * @param requestId The request ID for logging context
     * @return A StatusRuntimeException with mapped status
     */
    fun toStatusException(throwable: Throwable, requestId: String): StatusRuntimeException {
        val status = mapToStatus(throwable, requestId)
        return status.asRuntimeException()
    }

    /**
     * Gets a human-readable error code for logging purposes.
     * 
     * @param status The gRPC status
     * @return An error code string or null if status is OK
     */
    fun getErrorCode(status: Status?): String? {
        if (status == null || status.isOk) {
            return null
        }
        return status.code.name
    }

    /**
     * Gets a formatted error message for logging.
     * 
     * @param status The gRPC status
     * @return A formatted error message or null if status is OK
     */
    fun getErrorMessage(status: Status?): String? {
        if (status == null || status.isOk) {
            return null
        }
        
        val description = status.description
        if (!description.isNullOrEmpty()) {
            return description
        }
        
        return status.code.name
    }
}
