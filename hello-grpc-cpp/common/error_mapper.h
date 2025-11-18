/**
 * @file error_mapper.h
 * @brief Error mapping and retry logic for gRPC operations
 */

#ifndef HELLO_GRPC_ERROR_MAPPER_H
#define HELLO_GRPC_ERROR_MAPPER_H

#include <chrono>
#include <functional>
#include <map>
#include <string>
#include <thread>

#include <grpcpp/grpcpp.h>
#include <glog/logging.h>

namespace hello {

/**
 * @brief Configuration for retry logic
 */
struct RetryConfig {
  int max_retries;
  std::chrono::milliseconds initial_delay;
  std::chrono::milliseconds max_delay;
  double multiplier;

  /**
   * @brief Creates default retry configuration
   * @return Default RetryConfig with 3 retries, 2s initial delay, 30s max delay, 2.0 multiplier
   */
  static RetryConfig Default() {
    return RetryConfig{
      3,                                    // max_retries
      std::chrono::milliseconds(2000),      // initial_delay (2 seconds)
      std::chrono::milliseconds(30000),     // max_delay (30 seconds)
      2.0                                   // multiplier
    };
  }
};

/**
 * @brief Error mapper class for gRPC status codes
 */
class ErrorMapper {
public:
  /**
   * @brief Maps gRPC status code to human-readable message
   * @param status The gRPC status
   * @return Human-readable error message
   */
  static std::string MapGrpcError(const grpc::Status& status) {
    if (status.ok()) {
      return "Success";
    }

    std::string description = GetStatusDescription(status.error_code());
    std::string message = status.error_message();

    if (!message.empty()) {
      return description + ": " + message;
    }
    return description;
  }

  /**
   * @brief Determines if an error should be retried
   * @param status The gRPC status
   * @return true if the error is retryable, false otherwise
   */
  static bool IsRetryableError(const grpc::Status& status) {
    if (status.ok()) {
      return false;
    }

    grpc::StatusCode code = status.error_code();
    switch (code) {
      case grpc::StatusCode::UNAVAILABLE:
      case grpc::StatusCode::DEADLINE_EXCEEDED:
      case grpc::StatusCode::RESOURCE_EXHAUSTED:
      case grpc::StatusCode::INTERNAL:
        return true;
      default:
        return false;
    }
  }

  /**
   * @brief Handles RPC errors with logging and context
   * @param status The gRPC status
   * @param operation The operation name
   * @param context Additional context information
   */
  static void HandleRpcError(const grpc::Status& status, const std::string& operation,
                            const std::map<std::string, std::string>& context = {}) {
    if (status.ok()) {
      return;
    }

    std::string error_msg = MapGrpcError(status);
    std::string context_str;
    
    for (const auto& [key, value] : context) {
      if (!context_str.empty()) {
        context_str += ", ";
      }
      context_str += key + "=" + value;
    }

    if (IsRetryableError(status)) {
      LOG(WARNING) << "Retryable error occurred: operation=" << operation 
                   << ", error=" << error_msg
                   << (context_str.empty() ? "" : ", " + context_str);
    } else {
      LOG(ERROR) << "Non-retryable error occurred: operation=" << operation 
                 << ", error=" << error_msg
                 << (context_str.empty() ? "" : ", " + context_str);
    }
  }

  /**
   * @brief Executes a function with exponential backoff retry logic
   * @tparam Func Function type that returns grpc::Status
   * @param operation The operation name for logging
   * @param func The function to execute
   * @param config The retry configuration
   * @return The final status after all retry attempts
   */
  template<typename Func>
  static grpc::Status RetryWithBackoff(const std::string& operation, Func func, 
                                      const RetryConfig& config = RetryConfig::Default()) {
    grpc::Status last_status;
    auto delay = config.initial_delay;

    for (int attempt = 0; attempt <= config.max_retries; attempt++) {
      if (attempt > 0) {
        LOG(INFO) << "Retry attempt " << attempt << "/" << config.max_retries 
                  << " for " << operation << " after " << delay.count() << "ms";
        
        std::this_thread::sleep_for(delay);
      }

      last_status = func();
      
      if (last_status.ok()) {
        if (attempt > 0) {
          LOG(INFO) << "Operation " << operation << " succeeded after " 
                    << (attempt + 1) << " attempts";
        }
        return last_status;
      }

      if (!IsRetryableError(last_status)) {
        LOG(WARNING) << "Non-retryable error for " << operation << ": " 
                     << MapGrpcError(last_status);
        return last_status;
      }

      if (attempt < config.max_retries) {
        // Calculate next delay with exponential backoff
        delay = std::chrono::milliseconds(
          static_cast<long long>(delay.count() * config.multiplier)
        );
        if (delay > config.max_delay) {
          delay = config.max_delay;
        }
      }
    }

    LOG(ERROR) << "Operation " << operation << " failed after " 
               << (config.max_retries + 1) << " attempts: " 
               << MapGrpcError(last_status);
    
    return grpc::Status(grpc::StatusCode::ABORTED, 
                       "Max retries exceeded for " + operation);
  }

private:
  /**
   * @brief Gets human-readable description for a gRPC status code
   * @param code The status code
   * @return Human-readable description
   */
  static std::string GetStatusDescription(grpc::StatusCode code) {
    switch (code) {
      case grpc::StatusCode::OK:
        return "Success";
      case grpc::StatusCode::CANCELLED:
        return "Operation cancelled";
      case grpc::StatusCode::UNKNOWN:
        return "Unknown error";
      case grpc::StatusCode::INVALID_ARGUMENT:
        return "Invalid request parameters";
      case grpc::StatusCode::DEADLINE_EXCEEDED:
        return "Request timeout";
      case grpc::StatusCode::NOT_FOUND:
        return "Resource not found";
      case grpc::StatusCode::ALREADY_EXISTS:
        return "Resource already exists";
      case grpc::StatusCode::PERMISSION_DENIED:
        return "Permission denied";
      case grpc::StatusCode::RESOURCE_EXHAUSTED:
        return "Resource exhausted";
      case grpc::StatusCode::FAILED_PRECONDITION:
        return "Precondition failed";
      case grpc::StatusCode::ABORTED:
        return "Operation aborted";
      case grpc::StatusCode::OUT_OF_RANGE:
        return "Out of range";
      case grpc::StatusCode::UNIMPLEMENTED:
        return "Not implemented";
      case grpc::StatusCode::INTERNAL:
        return "Internal server error";
      case grpc::StatusCode::UNAVAILABLE:
        return "Service unavailable";
      case grpc::StatusCode::DATA_LOSS:
        return "Data loss";
      case grpc::StatusCode::UNAUTHENTICATED:
        return "Authentication required";
      default:
        return "Unknown error code";
    }
  }
};

} // namespace hello

#endif // HELLO_GRPC_ERROR_MAPPER_H
