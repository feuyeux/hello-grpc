package org.feuyeux.grpc.common;

import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import java.util.HashMap;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;

/**
 * Error mapper for translating gRPC status codes to human-readable messages and determining whether
 * an error is retryable.
 */
@Slf4j
public class ErrorMapper {

  /**
   * Maps gRPC status codes to human-readable error messages
   *
   * @param throwable The exception to map
   * @return Human-readable error message
   */
  public static String mapGrpcError(Throwable throwable) {
    if (throwable == null) {
      return "Success";
    }

    Status status;
    String message = "";

    if (throwable instanceof StatusRuntimeException) {
      StatusRuntimeException sre = (StatusRuntimeException) throwable;
      status = sre.getStatus();
      message = status.getDescription() != null ? status.getDescription() : "";
    } else {
      return "Unknown error: " + throwable.getMessage();
    }

    String description = getStatusDescription(status.getCode());

    if (!message.isEmpty()) {
      return description + ": " + message;
    }
    return description;
  }

  /**
   * Gets a human-readable description for a gRPC status code
   *
   * @param code The status code
   * @return Human-readable description
   */
  private static String getStatusDescription(Status.Code code) {
    switch (code) {
      case OK:
        return "Success";
      case CANCELLED:
        return "Operation cancelled";
      case UNKNOWN:
        return "Unknown error";
      case INVALID_ARGUMENT:
        return "Invalid request parameters";
      case DEADLINE_EXCEEDED:
        return "Request timeout";
      case NOT_FOUND:
        return "Resource not found";
      case ALREADY_EXISTS:
        return "Resource already exists";
      case PERMISSION_DENIED:
        return "Permission denied";
      case RESOURCE_EXHAUSTED:
        return "Resource exhausted";
      case FAILED_PRECONDITION:
        return "Precondition failed";
      case ABORTED:
        return "Operation aborted";
      case OUT_OF_RANGE:
        return "Out of range";
      case UNIMPLEMENTED:
        return "Not implemented";
      case INTERNAL:
        return "Internal server error";
      case UNAVAILABLE:
        return "Service unavailable";
      case DATA_LOSS:
        return "Data loss";
      case UNAUTHENTICATED:
        return "Authentication required";
      default:
        return "Unknown error code";
    }
  }

  /**
   * Determines if an error should be retried
   *
   * @param throwable The exception to check
   * @return true if the error is retryable, false otherwise
   */
  public static boolean isRetryableError(Throwable throwable) {
    if (throwable == null) {
      return false;
    }

    if (!(throwable instanceof StatusRuntimeException)) {
      return false;
    }

    StatusRuntimeException sre = (StatusRuntimeException) throwable;
    Status.Code code = sre.getStatus().getCode();

    switch (code) {
      case UNAVAILABLE:
      case DEADLINE_EXCEEDED:
      case RESOURCE_EXHAUSTED:
      case INTERNAL:
        return true;
      default:
        return false;
    }
  }

  /**
   * Handles RPC errors with logging and context
   *
   * @param throwable The exception that occurred
   * @param operation The operation name
   * @param context Additional context information
   */
  public static void handleRpcError(
      Throwable throwable, String operation, Map<String, Object> context) {
    if (throwable == null) {
      return;
    }

    String errorMsg = mapGrpcError(throwable);
    Map<String, Object> logContext = new HashMap<>(context);
    logContext.put("operation", operation);
    logContext.put("error", errorMsg);

    if (isRetryableError(throwable)) {
      log.warn("Retryable error occurred: {}", logContext);
    } else {
      log.error("Non-retryable error occurred: {}", logContext);
    }
  }
}
