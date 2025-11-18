package org.feuyeux.grpc.common;

import io.grpc.Metadata;
import io.grpc.Status;
import org.slf4j.Logger;

/**
 * Unified log formatter for gRPC services.
 *
 * <p>Provides consistent logging format across all RPC methods with standard fields: service,
 * request_id, method, peer, secure, duration_ms, status
 */
public class LogFormatter {
  private static final String SERVICE_NAME = "java";

  /**
   * Logs the start of an RPC request.
   *
   * @param logger The logger instance
   * @param method The RPC method name
   * @param requestId The request ID from metadata
   * @param peer The client address
   * @param secure Whether TLS is enabled
   */
  public static void logRequestStart(
      Logger logger, String method, String requestId, String peer, boolean secure) {
    logger.info(
        "service={} request_id={} method={} peer={} secure={} status=STARTED",
        SERVICE_NAME,
        requestId != null ? requestId : "unknown",
        method,
        peer,
        secure);
  }

  /**
   * Logs the completion of an RPC request.
   *
   * @param logger The logger instance
   * @param method The RPC method name
   * @param requestId The request ID from metadata
   * @param peer The client address
   * @param secure Whether TLS is enabled
   * @param durationMs Request duration in milliseconds
   * @param status gRPC status code
   */
  public static void logRequestEnd(
      Logger logger,
      String method,
      String requestId,
      String peer,
      boolean secure,
      long durationMs,
      Status status) {
    logger.info(
        "service={} request_id={} method={} peer={} secure={} duration_ms={} status={}",
        SERVICE_NAME,
        requestId != null ? requestId : "unknown",
        method,
        peer,
        secure,
        durationMs,
        status.getCode());
  }

  /**
   * Logs an error during RPC processing.
   *
   * @param logger The logger instance
   * @param method The RPC method name
   * @param requestId The request ID from metadata
   * @param peer The client address
   * @param secure Whether TLS is enabled
   * @param durationMs Request duration in milliseconds
   * @param status gRPC status code
   * @param errorCode Error classification code
   * @param message Error message
   * @param throwable Optional throwable for stack trace
   */
  public static void logRequestError(
      Logger logger,
      String method,
      String requestId,
      String peer,
      boolean secure,
      long durationMs,
      Status status,
      String errorCode,
      String message,
      Throwable throwable) {
    if (throwable != null) {
      logger.error(
          "service={} request_id={} method={} peer={} secure={} duration_ms={} status={} error_code={} message={}",
          SERVICE_NAME,
          requestId != null ? requestId : "unknown",
          method,
          peer,
          secure,
          durationMs,
          status.getCode(),
          errorCode,
          message,
          throwable);
    } else {
      logger.error(
          "service={} request_id={} method={} peer={} secure={} duration_ms={} status={} error_code={} message={}",
          SERVICE_NAME,
          requestId != null ? requestId : "unknown",
          method,
          peer,
          secure,
          durationMs,
          status.getCode(),
          errorCode,
          message);
    }
  }

  /**
   * Extracts request ID from metadata.
   *
   * @param metadata The gRPC metadata
   * @return The request ID or null if not found
   */
  public static String extractRequestId(Metadata metadata) {
    // Try multiple request ID header variants
    String requestId =
        metadata.get(Metadata.Key.of("x-request-id", Metadata.ASCII_STRING_MARSHALLER));
    if (requestId == null) {
      requestId = metadata.get(Metadata.Key.of("request-id", Metadata.ASCII_STRING_MARSHALLER));
    }
    return requestId;
  }
}
