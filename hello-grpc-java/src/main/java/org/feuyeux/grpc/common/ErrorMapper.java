package org.feuyeux.grpc.common;

import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;
import lombok.extern.slf4j.Slf4j;

/**
 * Error mapper for translating gRPC status codes to human-readable messages and implementing retry
 * logic with exponential backoff.
 */
@Slf4j
public class ErrorMapper {

  /** Configuration for retry logic */
  public static class RetryConfig {
    private final int maxRetries;
    private final Duration initialDelay;
    private final Duration maxDelay;
    private final double multiplier;

    public RetryConfig(
        int maxRetries, Duration initialDelay, Duration maxDelay, double multiplier) {
      this.maxRetries = maxRetries;
      this.initialDelay = initialDelay;
      this.maxDelay = maxDelay;
      this.multiplier = multiplier;
    }

    public static RetryConfig defaultConfig() {
      return new RetryConfig(3, Duration.ofSeconds(2), Duration.ofSeconds(30), 2.0);
    }

    public int getMaxRetries() {
      return maxRetries;
    }

    public Duration getInitialDelay() {
      return initialDelay;
    }

    public Duration getMaxDelay() {
      return maxDelay;
    }

    public double getMultiplier() {
      return multiplier;
    }
  }

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

  /**
   * Executes a function with exponential backoff retry logic
   *
   * @param operation The operation name for logging
   * @param supplier The function to execute
   * @param config The retry configuration
   * @param <T> The return type
   * @return The result of the function
   * @throws Exception if all retries are exhausted
   */
  public static <T> T retryWithBackoff(String operation, Supplier<T> supplier, RetryConfig config)
      throws Exception {
    Exception lastException = null;
    long delayMillis = config.getInitialDelay().toMillis();

    for (int attempt = 0; attempt <= config.getMaxRetries(); attempt++) {
      if (attempt > 0) {
        log.info(
            "Retry attempt {}/{} for {} after {}ms",
            attempt,
            config.getMaxRetries(),
            operation,
            delayMillis);

        try {
          TimeUnit.MILLISECONDS.sleep(delayMillis);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
          throw new Exception("Operation cancelled: " + e.getMessage(), e);
        }
      }

      try {
        T result = supplier.get();
        if (attempt > 0) {
          log.info("Operation {} succeeded after {} attempts", operation, attempt + 1);
        }
        return result;
      } catch (Exception e) {
        lastException = e;

        if (!isRetryableError(e)) {
          log.warn("Non-retryable error for {}: {}", operation, mapGrpcError(e));
          throw e;
        }

        if (attempt < config.getMaxRetries()) {
          // Calculate next delay with exponential backoff
          delayMillis = (long) (delayMillis * config.getMultiplier());
          if (delayMillis > config.getMaxDelay().toMillis()) {
            delayMillis = config.getMaxDelay().toMillis();
          }
        }
      }
    }

    log.error(
        "Operation {} failed after {} attempts: {}",
        operation,
        config.getMaxRetries() + 1,
        mapGrpcError(lastException));
    throw new Exception("Max retries exceeded for " + operation, lastException);
  }

  /**
   * Executes a runnable with exponential backoff retry logic
   *
   * @param operation The operation name for logging
   * @param runnable The function to execute
   * @param config The retry configuration
   * @throws Exception if all retries are exhausted
   */
  public static void retryWithBackoff(String operation, Runnable runnable, RetryConfig config)
      throws Exception {
    retryWithBackoff(
        operation,
        () -> {
          runnable.run();
          return null;
        },
        config);
  }
}
