package org.feuyeux.grpc

import io.grpc.Metadata
import io.grpc.Status
import org.apache.logging.log4j.Logger

/**
 * Unified log formatter for gRPC services.
 *
 * Provides consistent logging format across all RPC methods with standard fields:
 * service, request_id, method, peer, secure, duration_ms, status
 */
object LogFormatter {
    private const val SERVICE_NAME = "kotlin"
    private val isSecure = System.getenv("GRPC_HELLO_SECURE") == "Y"

    /**
     * Logs the start of an RPC request.
     */
    fun logRequestStart(
        logger: Logger,
        method: String,
        requestId: String?,
        peer: String,
        secure: Boolean = isSecure
    ) {
        logger.info(
            "service={} request_id={} method={} peer={} secure={} status=STARTED",
            SERVICE_NAME,
            requestId ?: "unknown",
            method,
            peer,
            secure
        )
    }

    /**
     * Logs the completion of an RPC request.
     */
    fun logRequestEnd(
        logger: Logger,
        method: String,
        requestId: String?,
        peer: String,
        secure: Boolean = isSecure,
        durationMs: Long,
        status: Status
    ) {
        logger.info(
            "service={} request_id={} method={} peer={} secure={} duration_ms={} status={}",
            SERVICE_NAME,
            requestId ?: "unknown",
            method,
            peer,
            secure,
            durationMs,
            status.code
        )
    }

    /**
     * Logs an error during RPC processing.
     */
    fun logRequestError(
        logger: Logger,
        method: String,
        requestId: String?,
        peer: String,
        secure: Boolean = isSecure,
        durationMs: Long,
        status: Status,
        errorCode: String,
        message: String?,
        throwable: Throwable? = null
    ) {
        if (throwable != null) {
            logger.error(
                "service={} request_id={} method={} peer={} secure={} duration_ms={} status={} error_code={} message={}",
                SERVICE_NAME,
                requestId ?: "unknown",
                method,
                peer,
                secure,
                durationMs,
                status.code,
                errorCode,
                message,
                throwable
            )
        } else {
            logger.error(
                "service={} request_id={} method={} peer={} secure={} duration_ms={} status={} error_code={} message={}",
                SERVICE_NAME,
                requestId ?: "unknown",
                method,
                peer,
                secure,
                durationMs,
                status.code,
                errorCode,
                message
            )
        }
    }

    /**
     * Extracts request ID from metadata.
     */
    fun extractRequestId(metadata: Metadata): String? {
        // Try multiple request ID header variants
        var requestId = metadata.get(Metadata.Key.of("x-request-id", Metadata.ASCII_STRING_MARSHALLER))
        if (requestId == null) {
            requestId = metadata.get(Metadata.Key.of("request-id", Metadata.ASCII_STRING_MARSHALLER))
        }
        return requestId
    }
}
